import 'dart:async';
import 'dart:io';

import 'package:PiliPlus/common/dial_prefix.dart';
import 'package:PiliPlus/common/widgets/button/icon_button.dart';
import 'package:PiliPlus/common/widgets/radio_widget.dart';
import 'package:PiliPlus/http/init.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/http/login.dart';
import 'package:PiliPlus/models/common/account_type.dart';
import 'package:PiliPlus/models/login/model.dart';
import 'package:PiliPlus/pages/login/geetest/geetest_webview_dialog.dart';
import 'package:PiliPlus/utils/accounts.dart';
import 'package:PiliPlus/utils/accounts/account.dart';
import 'package:PiliPlus/utils/platform_utils.dart';
import 'package:PiliPlus/utils/theme_utils.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

typedef LoginQrCode = ({String authCode, String url});
typedef LoginQrLoader = Future<LoadingState<LoginQrCode>> Function();
typedef LoginQrPoller = Future<dynamic> Function(String authCode);

class LoginPageController extends GetxController
    with GetSingleTickerProviderStateMixin {
  LoginPageController({
    this.initialTab = 1,
    LoginQrLoader? qrLoader,
    LoginQrPoller? qrPoller,
    this.onQrAuthenticated,
  }) : _qrLoader = qrLoader ?? LoginHttp.getHDcode,
       _qrPoller = qrPoller ?? LoginHttp.codePoll;

  final LoginQrLoader _qrLoader;
  final LoginQrPoller _qrPoller;
  final Future<void> Function(Map data)? onQrAuthenticated;
  final int initialTab;
  final TextEditingController telTextController = TextEditingController();
  final TextEditingController usernameTextController = TextEditingController();
  final TextEditingController passwordTextController = TextEditingController();
  final TextEditingController smsCodeTextController = TextEditingController();
  final TextEditingController cookieTextController = TextEditingController();

  late final codeInfo = LoadingState<LoginQrCode>.loading().obs;

  late final TabController tabController;

  late final CaptchaDataModel captchaData = CaptchaDataModel();
  late final RxInt qrCodeLeftTime = 180.obs;
  late final RxString statusQRCode = ''.obs;

  late var selectedCountryCodeId = Login.dialPrefix.first;
  late String captchaKey = '';
  late final RxInt smsSendCooldown = 0.obs;
  late int smsSendTimestamp = 0;

  // 定时器
  Timer? qrCodeTimer;
  Timer? smsSendCooldownTimer;

  int _qrGeneration = 0;
  int? _pollingGeneration;
  bool _qrTabActive = false;
  bool _closed = false;

  bool _isCurrentQr(int generation) =>
      !_closed && _qrTabActive && generation == _qrGeneration;

  @override
  void onInit() {
    super.onInit();
    tabController = TabController(
      length: 4,
      initialIndex: initialTab,
      vsync: this,
    )..addListener(_handleTabChange);
    _handleTabChange();
  }

  @override
  void onClose() {
    _closed = true;
    _qrGeneration++;
    tabController
      ..removeListener(_handleTabChange)
      ..dispose();
    qrCodeTimer?.cancel();
    smsSendCooldownTimer?.cancel();
    telTextController.dispose();
    usernameTextController.dispose();
    passwordTextController.dispose();
    smsCodeTextController.dispose();
    cookieTextController.dispose();
    super.onClose();
  }

  Future<void> refreshQRCode() async {
    if (_closed || !_qrTabActive) return;
    final generation = ++_qrGeneration;
    qrCodeTimer?.cancel();
    codeInfo.value = LoadingState<LoginQrCode>.loading();
    qrCodeLeftTime.value = 0;
    statusQRCode.value = '正在生成二维码';
    try {
      final res = await _qrLoader();
      if (!_isCurrentQr(generation)) return;
      if (res case Success(:final response)) {
        if (response.authCode.isEmpty || response.url.isEmpty) {
          throw const FormatException('Empty QR code');
        }
        codeInfo.value = res;
        qrCodeLeftTime.value = 180;
        statusQRCode.value = '等待扫码';
        qrCodeTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (!_isCurrentQr(generation)) {
            timer.cancel();
            return;
          }
          qrCodeLeftTime.value = (180 - timer.tick).clamp(0, 180);
          if (qrCodeLeftTime.value == 0) {
            _expireQr();
          } else if (_pollingGeneration != generation) {
            unawaited(_pollQRCode(response.authCode, generation));
          }
        });
      } else {
        codeInfo.value = const Error('二维码加载失败，请检查网络后重试');
        statusQRCode.value = '';
      }
    } catch (_) {
      if (!_isCurrentQr(generation)) return;
      codeInfo.value = const Error('二维码加载失败，请检查网络后重试');
      statusQRCode.value = '';
    }
  }

  void _expireQr([String message = '二维码已过期，请刷新']) {
    qrCodeTimer?.cancel();
    qrCodeLeftTime.value = 0;
    statusQRCode.value = message;
    // A poll already in flight must not sign in with this expired code.
    _qrGeneration++;
  }

  Future<void> _pollQRCode(String authCode, int generation) async {
    _pollingGeneration = generation;
    var authenticating = false;
    try {
      final value = await _qrPoller(authCode);
      if (!_isCurrentQr(generation)) return;
      if (value['status'] == true) {
        qrCodeTimer?.cancel();
        authenticating = true;
        qrCodeLeftTime.value = 0;
        statusQRCode.value = '正在完成登录';
        final Map data = value['data'];
        if (onQrAuthenticated case final complete?) {
          await complete(data);
        } else {
          await setAccount(data, data['cookie_info']['cookies']);
        }
        if (!_isCurrentQr(generation)) return;
        statusQRCode.value = '扫码成功';
        if (onQrAuthenticated == null) Get.back();
      } else if (value['code'] == 86038) {
        _expireQr();
      } else {
        statusQRCode.value = switch (value['code']) {
          86101 => '等待扫码',
          86090 => '扫码成功，请在 bilibili App 中确认',
          _ => '等待确认，正在检查登录状态',
        };
      }
    } catch (_) {
      if (!_isCurrentQr(generation)) return;
      if (authenticating) {
        _expireQr('登录未完成，请刷新二维码重试');
      } else {
        statusQRCode.value = '网络暂时不可用，正在重试';
      }
    } finally {
      if (_pollingGeneration == generation) _pollingGeneration = null;
    }
  }

  void _handleTabChange() {
    final active = tabController.index == 2;
    if (active == _qrTabActive) return;
    _qrTabActive = active;
    if (active) {
      unawaited(refreshQRCode());
    } else {
      _qrGeneration++;
      qrCodeTimer?.cancel();
    }
  }

  // 申请极验验证码
  void getCaptcha(
    String geeGt,
    String geeChallenge,
    VoidCallback onSuccess,
  ) {
    GeetestWebviewDialog.geetest(geeGt, geeChallenge).then((res) {
      if (res != null) {
        captchaData
          ..validate = res['geetest_validate']
          ..seccode = res['geetest_seccode']
          ..geetest = GeetestData(
            challenge: res['geetest_challenge'],
            gt: geeGt,
          );
        SmartDialog.showToast('验证成功');
        onSuccess();
      }
    });
  }

  static String validateCookie(String cookie) {
    return cookie
        .split(';')
        .where((e) {
          try {
            Cookie.fromSetCookieValue(e.trim());
          } catch (_) {
            return false;
          }
          return true;
        })
        .join(';');
  }

  // cookie登录
  Future<void> loginByCookie() async {
    if (cookieTextController.text.isEmpty) {
      SmartDialog.showToast('cookie不能为空');
      return;
    }
    try {
      final result = await Request().get(
        "/x/member/web/account",
        options: Options(
          headers: {
            "cookie": validateCookie(cookieTextController.text),
          },
          extra: {'account': AnonymousAccount()},
        ),
      );
      if (result.data['code'] == 0) {
        try {
          await LoginAccount(
            BiliCookieJar.fromJson(
              Map.fromEntries(
                cookieTextController.text.split(';').map((item) {
                  final list = item.split('=');
                  return MapEntry(list.first, list.skip(1).join());
                }),
              ),
            ),
            null,
            null,
          ).onChange();
          if (!Accounts.main.isLogin) await switchAccountDialog(Get.context!);
          SmartDialog.showToast('登录成功');
          Get.back();
        } catch (e) {
          SmartDialog.showToast("登录失败: $e");
        }
      } else {
        SmartDialog.showToast("哔哩哔哩登录已失效，请重新登录");
      }
    } catch (e) {
      SmartDialog.showToast("获取哔哩哔哩用户信息失败，可前往账号管理重试");
    }
  }

  // app端密码登录
  Future<void> loginByPassword() async {
    String username = usernameTextController.text;
    String password = passwordTextController.text;
    if (username.isEmpty || password.isEmpty) {
      SmartDialog.showToast('用户名或密码不能为空');
      return;
    }
    // if ((passwordFormKey.currentState as FormState).validate()) {
    final webKeyRes = await LoginHttp.getWebKey();
    if (!webKeyRes['status']) {
      SmartDialog.showToast(webKeyRes['msg']);
      return;
    }
    String salt = webKeyRes['data']['hash'];
    String key = webKeyRes['data']['key'];
    final res = await LoginHttp.loginByPwd(
      username: username,
      password: password,
      key: key,
      salt: salt,
      geeValidate: captchaData.validate,
      geeSeccode: captchaData.seccode,
      geeChallenge: captchaData.geetest?.challenge,
      recaptchaToken: captchaData.token,
    );
    if (res['status']) {
      final data = res['data'];
      if (data == null) {
        SmartDialog.showToast('登录异常，接口未返回数据：${res["msg"]}');
        return;
      }
      if (data['status'] == 2) {
        SmartDialog.showToast(data['message']);
        // return;
        //{"code":0,"message":"0","ttl":1,"data":{"status":2,"message":"本次登录环境存在风险, 需使用手机号进行验证或绑定","url":"https://passport.bilibili.com/h5-app/passport/risk/verify?tmp_token=9e785433940891dfa78f033fb7928181&request_id=e5a6d6480df04097870be56c6e60f7ef&source=risk","token_info":null,"cookie_info":null,"sso":null,"is_new":false,"is_tourist":false}}
        String url = data['url']!;
        Uri currentUri = Uri.parse(url);
        final safeCenterRes = await LoginHttp.safeCenterGetInfo(
          tmpCode: currentUri.queryParameters['tmp_token']!,
        );
        //{"code":0,"message":"0","ttl":1,"data":{"account_info":{"hide_tel":"111*****111","hide_mail":"aaa*****aaaa.aaa","bind_mail":true,"bind_tel":true,"tel_verify":true,"mail_verify":true,"unneeded_check":false,"bind_safe_question":false,"mid":1111111},"member_info":{"nickname":"xxxxxxx","face":"https://i0.hdslb.com/bfs/face/xxxxxxx.jpg","realname_status":false},"sns_info":{"bind_google":false,"bind_fb":false,"bind_apple":false,"bind_qq":true,"bind_weibo":true,"bind_wechat":false},"account_safe":{"score":80}}}
        if (!safeCenterRes['status']) {
          SmartDialog.showToast(
            "获取安全验证信息失败，请尝试其它登录方式\n"
            "(${safeCenterRes['code']}) ${safeCenterRes['msg']}",
          );
          return;
        }
        Map<String, String> accountInfo = {
          "hindTel": safeCenterRes['data']['account_info']!["hide_tel"],
          "hindMail": safeCenterRes['data']['account_info']!["hide_mail"],
        };
        if (!safeCenterRes['data']['account_info']!['tel_verify']) {
          SmartDialog.showToast("当前账号未支持手机号验证，请尝试其它登录方式");
          return;
        }

        TextEditingController textFieldController = TextEditingController();
        String captchaKey = '';
        showDialog(
          context: Get.context!,
          builder: (context) => AlertDialog(
            titlePadding: const EdgeInsets.only(
              left: 16,
              top: 18,
              right: 16,
              bottom: 12,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            actionsPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            title: const Text(
              "本次登录需要验证您的手机号",
              textAlign: TextAlign.center,
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  accountInfo['hindTel'] ?? '未能获取手机号',
                  style: const TextStyle(fontSize: 18),
                ),
                // 带有清空按钮的输入框
                TextField(
                  style: const TextStyle(fontSize: 15),
                  controller: textFieldController,
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    hintText: "请输入短信验证码",
                    hintStyle: const TextStyle(fontSize: 15),
                    suffixIcon: iconButton(
                      icon: const Icon(Icons.clear),
                      size: 32,
                      onPressed: textFieldController.clear,
                    ),
                    suffixIconConstraints: const BoxConstraints(
                      maxHeight: 32,
                      maxWidth: 32,
                    ),
                  ),
                ),
              ],
            ),
            actions: <Widget>[
              TextButton(
                child: const Text("发送验证码"),
                onPressed: () async {
                  final preCaptureRes = await LoginHttp.preCapture();
                  if (!preCaptureRes['status'] ||
                      preCaptureRes['data'] == null) {
                    SmartDialog.showToast(
                      "获取验证码失败，请尝试其它登录方式\n"
                      "(${preCaptureRes['code']}) ${preCaptureRes['msg']} ${preCaptureRes['data']}",
                    );
                  }
                  String geeGt = preCaptureRes['data']['gee_gt'];
                  String geeChallenge = preCaptureRes['data']['gee_challenge'];
                  captchaData.token = preCaptureRes['data']['recaptcha_token'];
                  if (!isGeeArgumentValid(geeGt, geeChallenge)) {
                    SmartDialog.showToast(
                      "获取极验参数为空，请尝试其它登录方式\n"
                      "(${preCaptureRes['code']}) ${preCaptureRes['msg']} ${preCaptureRes['data']}",
                    );
                    return;
                  }

                  getCaptcha(
                    geeGt,
                    geeChallenge,
                    () async {
                      final safeCenterSendSmsCodeRes =
                          await LoginHttp.safeCenterSmsCode(
                            tmpCode: currentUri.queryParameters['tmp_token']!,
                            geeChallenge: geeChallenge,
                            geeSeccode: captchaData.seccode,
                            geeValidate: captchaData.validate,
                            recaptchaToken: captchaData.token,
                            refererUrl: url,
                          );
                      if (!safeCenterSendSmsCodeRes['status']) {
                        SmartDialog.showToast(
                          "发送短信验证码失败，请尝试其它登录方式\n"
                          "(${safeCenterSendSmsCodeRes['code']}) ${safeCenterSendSmsCodeRes['msg']}",
                        );
                        return;
                      }
                      SmartDialog.showToast("短信验证码已发送，请查收");
                      captchaKey =
                          safeCenterSendSmsCodeRes['data']['captcha_key'];
                    },
                  );
                },
              ),
              TextButton(
                onPressed: Get.back,
                child: Text(
                  "取消",
                  style: TextStyle(color: ThemeUtils.theme.colorScheme.outline),
                ),
              ),
              TextButton(
                onPressed: () async {
                  String? code = textFieldController.text;
                  if (code.isEmpty) {
                    SmartDialog.showToast("请输入短信验证码");
                    return;
                  }
                  final safeCenterSmsVerifyRes =
                      await LoginHttp.safeCenterSmsVerify(
                        code: code,
                        tmpCode: currentUri.queryParameters['tmp_token']!,
                        requestId: currentUri.queryParameters['request_id']!,
                        source: currentUri.queryParameters['source']!,
                        captchaKey: captchaKey,
                        refererUrl: url,
                      );
                  if (!safeCenterSmsVerifyRes['status']) {
                    SmartDialog.showToast(
                      "验证短信验证码失败，请尝试其它登录方式\n"
                      "(${safeCenterSmsVerifyRes['code']}) ${safeCenterSmsVerifyRes['msg']}",
                    );
                    return;
                  }
                  SmartDialog.showToast("验证成功，正在登录");
                  final oauth2AccessTokenRes =
                      await LoginHttp.oauth2AccessToken(
                        code: safeCenterSmsVerifyRes['data']['code'],
                      );
                  if (!oauth2AccessTokenRes['status']) {
                    SmartDialog.showToast(
                      "登录失败，请尝试其它登录方式\n"
                      "(${oauth2AccessTokenRes['code']}) ${oauth2AccessTokenRes['msg']}",
                    );
                    return;
                  }
                  final data = oauth2AccessTokenRes['data'];
                  if (data['token_info'] == null ||
                      data['cookie_info'] == null) {
                    SmartDialog.showToast(
                      '登录异常，接口未返回身份信息，可能是因为账号风控，请尝试其它登录方式。\n${oauth2AccessTokenRes["msg"]}，\n $data',
                    );
                    return;
                  }
                  SmartDialog.showToast('正在保存身份信息');
                  await setAccount(
                    data['token_info'],
                    data['cookie_info']['cookies'],
                  );
                  Get
                    ..back()
                    ..back();
                },
                child: const Text("确认"),
              ),
            ],
          ),
        ).whenComplete(textFieldController.dispose);

        return;
      }
      if (data['token_info'] == null || data['cookie_info'] == null) {
        SmartDialog.showToast(
          '登录异常，接口未返回身份信息，可能是因为账号风控，请尝试其它登录方式。\n${res["msg"]}，\n $data',
        );
        return;
      }
      SmartDialog.showToast('正在保存身份信息');
      await setAccount(data['token_info'], data['cookie_info']['cookies']);
      Get.back();
    } else {
      // handle login result
      switch (res['code']) {
        case 0:
          // login success
          break;
        case -105:
          String captureUrl = res['data']['url'];
          Uri captureUri = Uri.parse(captureUrl);
          captchaData.token = captureUri.queryParameters['recaptcha_token']!;
          String geeGt = captureUri.queryParameters['gee_gt']!;
          String geeChallenge = captureUri.queryParameters['gee_challenge']!;

          getCaptcha(geeGt, geeChallenge, loginByPassword);
          break;
        default:
          SmartDialog.showToast(res['msg']);
          // login failed
          break;
      }
    }
    // }
  }

  // 短信验证码登录
  Future<void> loginBySmsCode() async {
    if (telTextController.text.isEmpty) {
      SmartDialog.showToast('手机号不能为空');
      return;
    }
    if (captchaKey.isEmpty) {
      SmartDialog.showToast('请先点击获取验证码');
      return;
    }
    if (smsCodeTextController.text.isEmpty) {
      SmartDialog.showToast('验证码不能为空');
      return;
    }
    if (DateTime.now().millisecondsSinceEpoch - smsSendTimestamp >
        1000 * 60 * 5) {
      SmartDialog.showToast('验证码已过期，请重新获取');
      return;
    }
    final webKeyRes = await LoginHttp.getWebKey();
    if (!webKeyRes['status']) {
      SmartDialog.showToast(webKeyRes['msg']);
      return;
    }
    String key = webKeyRes['data']['key'];
    final res = await LoginHttp.loginBySms(
      tel: telTextController.text,
      code: smsCodeTextController.text,
      captchaKey: captchaKey,
      cid: selectedCountryCodeId.countryId,
      key: key,
    );
    if (res['status']) {
      SmartDialog.showToast('登录成功');
      final data = res['data'];
      await setAccount(data['token_info'], data['cookie_info']['cookies']);
      Get.back();
    } else {
      SmartDialog.showToast(res['msg']);
    }
  }

  // app端验证码
  Future<void> sendSmsCode() async {
    if (telTextController.text.isEmpty) {
      SmartDialog.showToast('手机号不能为空');
      return;
    }
    // String? guestId;
    // final webKeyRes = await LoginHttp.getWebKey();
    // if (!webKeyRes['status']) {
    //   SmartDialog.showToast(webKeyRes['msg']);
    // } else {
    //   String key = webKeyRes['data']['key'];
    //   final guestIdRes = await LoginHttp.getGuestId(key);
    //   if (!guestIdRes['status']) {
    //     SmartDialog.showToast(guestIdRes['msg']);
    //   } else {
    //     guestId = guestIdRes['data']['guest_id'];
    //   }
    // }
    // final preCaptureRes = await LoginHttp.preCapture();
    // if (!preCaptureRes['status']) {
    //   SmartDialog.showToast("获取验证码失败，请尝试其它登录方式\n"
    //       "(${preCaptureRes['code']}) ${preCaptureRes['msg']}");
    //   return;
    // }
    // String geeGt = preCaptureRes['data']['gee_gt']!;
    // String geeChallenge = preCaptureRes['data']['gee_challenge'];
    // captchaData.token = preCaptureRes['data']['recaptcha_token']!;

    // getCaptcha(geeGt, geeChallenge, () async {

    // final safeCenterSendSmsCodeRes =
    // await LoginHttp.safeCenterSmsCode(
    //   tmpCode: currentUri.queryParameters['tmp_token']!,
    //   geeChallenge: geeChallenge,
    //   geeSeccode: captchaData.seccode!,
    //   geeValidate: captchaData.validate!,
    //   recaptchaToken: captchaData.token!,
    //   refererUrl: url,
    // );
    // if (!safeCenterSendSmsCodeRes['status']) {
    //   SmartDialog.showToast("发送短信验证码失败，请尝试其它登录方式\n"
    //       "(${safeCenterSendSmsCodeRes['code']}) ${safeCenterSendSmsCodeRes['msg']}");
    //   return;
    // }
    // SmartDialog.showToast("短信验证码已发送，请查收");
    // captchaKey = safeCenterSendSmsCodeRes['data']['captcha_key'];

    final res = await LoginHttp.sendSmsCode(
      tel: telTextController.text,
      cid: selectedCountryCodeId.countryId,
      // deviceTouristId: guestId,
      geeValidate: captchaData.validate,
      geeSeccode: captchaData.seccode,
      geeChallenge: captchaData.geetest?.challenge,
      recaptchaToken: captchaData.token,
    );
    if (res['status']) {
      SmartDialog.showToast('发送成功');
      smsSendTimestamp = DateTime.now().millisecondsSinceEpoch;
      smsSendCooldown.value = 60;
      captchaKey = res['data']['captcha_key'];
      smsSendCooldownTimer = Timer.periodic(const Duration(seconds: 1), (
        timer,
      ) {
        smsSendCooldown.value = 60 - timer.tick;
        if (smsSendCooldown <= 0) {
          smsSendCooldownTimer?.cancel();
          smsSendCooldown.value = 0;
        }
      });
    } else {
      // handle login result
      switch (res['code']) {
        case 0:
        case -105:
          String? captureUrl = res['data']?['recaptcha_url'];
          String? geeGt;
          String? geeChallenge;
          if (captureUrl != null && captureUrl.isNotEmpty) {
            Uri captureUri = Uri.parse(captureUrl);
            captchaData.token = captureUri.queryParameters['recaptcha_token'];
            geeGt = captureUri.queryParameters['gee_gt'];
            geeChallenge = captureUri.queryParameters['gee_challenge'];
          }

          if (!isGeeArgumentValid(geeGt, geeChallenge)) {
            if (kDebugMode) {
              debugPrint(
                '验证信息错误：${res["msg"]}\n返回内容：${res["data"]}，尝试另一个验证码接口',
              );
            }
            final preCaptureRes = await LoginHttp.preCapture();
            if (!preCaptureRes['status'] || preCaptureRes['data'] == null) {
              SmartDialog.showToast(
                "获取验证码失败，请尝试其它登录方式\n"
                "(${preCaptureRes['code']}) ${preCaptureRes['msg']} ${preCaptureRes['data']}",
              );
              return;
            }
            geeGt = preCaptureRes['data']['gee_gt'];
            geeChallenge = preCaptureRes['data']['gee_challenge'];
            captchaData.token = preCaptureRes['data']['recaptcha_token'];
          }

          if (!isGeeArgumentValid(geeGt, geeChallenge)) {
            SmartDialog.showToast("获取验证码失败，请尝试其它登录方式\n");
            return;
          }

          getCaptcha(geeGt!, geeChallenge!, sendSmsCode);
          break;
        default:
          SmartDialog.showToast(res['msg']);
          break;
      }
    }
  }

  bool isGeeArgumentValid(String? geeGt, String? geeChallenge) {
    return geeGt?.isNotEmpty == true &&
        geeChallenge?.isNotEmpty == true &&
        captchaData.token?.isNotEmpty == true;
  }

  Future<void> setAccount(Map tokenInfo, List cookieInfo) async {
    final account = LoginAccount(
      BiliCookieJar.fromList(cookieInfo),
      tokenInfo['access_token'],
      tokenInfo['refresh_token'],
    );
    await Future.wait([account.onChange(), AnonymousAccount().delete()]);
    for (int i = 0; i < AccountType.values.length; i++) {
      if (Accounts.accountMode[i].mid == account.mid) {
        Accounts.accountMode[i] = account;
      }
    }
    if (Accounts.main.isLogin) {
      SmartDialog.showToast('登录成功');
    } else {
      SmartDialog.showToast('登录成功, 请先设置账号模式');
      await switchAccountDialog(Get.context!);
    }
  }

  static Future<void>? switchAccountDialog(BuildContext context) {
    if (Accounts.account.isEmpty) {
      SmartDialog.showToast('请先登录');
      return Get.toNamed('/loginPage');
    }
    final colorScheme = ColorScheme.of(context);
    final selectAccount = List.of(Accounts.accountMode);
    final options = {
      AnonymousAccount(): '0',
      ...Accounts.account.toMap().map(
        (k, v) => MapEntry(v, k as String),
      ),
    };
    bool quickSelect = selectAccount.every((e) => e == selectAccount.first);
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          crossAxisAlignment: .start,
          mainAxisAlignment: .spaceBetween,
          children: [
            Text.rich(
              style: const TextStyle(height: 1.5),
              TextSpan(
                children: [
                  const TextSpan(text: '账号切换'),
                  TextSpan(
                    text: '\nmid为0时使用匿名',
                    style: TextStyle(fontSize: 14, color: colorScheme.outline),
                  ),
                ],
              ),
            ),
            TextButton(
              style: TextButton.styleFrom(
                visualDensity: .compact,
                tapTargetSize: .shrinkWrap,
              ),
              onPressed: () {
                quickSelect = !quickSelect;
                (context as Element).markNeedsBuild();
              },
              child: Text(quickSelect ? '详细' : '快速'),
            ),
          ],
        ),
        titlePadding: const .only(left: 22, top: 16, right: 22, bottom: 3),
        contentPadding: const .symmetric(vertical: 5),
        actionsPadding: const .only(left: 16, right: 16, bottom: 10),
        content: SingleChildScrollView(
          child: AnimatedSize(
            curve: Curves.easeIn,
            alignment: .topCenter,
            duration: const Duration(milliseconds: 200),
            child: quickSelect
                ? Builder(
                    builder: (context) => RadioGroup<Account>(
                      groupValue: selectAccount[0],
                      onChanged: (v) {
                        selectAccount.fillRange(0, selectAccount.length, v);
                        (context as Element).markNeedsBuild();
                      },
                      child: Column(
                        crossAxisAlignment: .start,
                        children: options.entries
                            .map(
                              (entry) => RadioWidget<Account>(
                                value: entry.key,
                                title: entry.value,
                                mainAxisSize: .max,
                                padding: PlatformUtils.isDesktop
                                    ? const .only(left: 12)
                                    : const .only(left: 12, top: 2, bottom: 2),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  )
                : Column(
                    crossAxisAlignment: .start,
                    children: AccountType.values
                        .map(
                          (e) => Builder(
                            builder: (context) => RadioGroup<Account>(
                              groupValue: selectAccount[e.index],
                              onChanged: (v) {
                                selectAccount[e.index] = v!;
                                (context as Element).markNeedsBuild();
                              },
                              child: WrapRadioOptionsGroup<Account>(
                                groupTitle: e.title,
                                options: options,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: Get.back,
            child: Text('取消', style: TextStyle(color: colorScheme.outline)),
          ),
          TextButton(
            onPressed: () {
              Get.back();
              for (final type in AccountType.values) {
                final index = type.index;
                final account = quickSelect
                    ? selectAccount.first
                    : selectAccount[index];
                if (account != Accounts.accountMode[index]) {
                  Accounts.set(type, account);
                }
              }
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }
}
