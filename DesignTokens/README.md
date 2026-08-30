# Newbili shared interface tokens

`newbili-theme.tokens.json` is the canonical DTCG source for the Fluent spacing,
shape, motion, touch-target, and platform color-role contract.

Regenerate the checked-in SwiftUI adapter after changing the token source:

```sh
swift DesignTokens/generate_adapters.swift \
  DesignTokens/newbili-theme.tokens.json \
  Newbili/Sources/DesignSystem/AppInterfaceTokenValues.generated.swift
```

The same generator accepts an optional Kotlin output path for the future Compose
adapter. Do not run it into `android/` until Android implementation work resumes.
