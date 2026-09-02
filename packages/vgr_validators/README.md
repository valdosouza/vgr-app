# vgr_validators

Format validators and input masks shared by `apps/mobile` and `apps/admin`
(decisions 153–157). See `app/docs/feature/validators.md`.

- `VgrValidators.*` — one method per API rule; returns a `VgrFieldError`
  (the API's per-field code, decision 83) or `null`.
- `VgrMask` + `VgrMaskFormatter` — CPF/CNPJ, BR phone, CEP masks; screens
  pass the enum to `VgrTextField.mask`.
- `unmask` — digits only, what the API receives.
- `isValidCpf` / `isValidCnpj` / `isValidBrTaxId` — mirror
  `api/src/modules/reward/br-tax-id.ts`.
