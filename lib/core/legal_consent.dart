const String munibLegalVersion = '2026-09-09';

bool canSubmitAuthAction({
  required bool isLogin,
  required bool acceptedLegal,
}) {
  return isLogin || acceptedLegal;
}
