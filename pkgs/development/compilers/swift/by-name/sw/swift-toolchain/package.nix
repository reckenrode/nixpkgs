{ swift }:

swift.override {
  toolchain-name = "swift-toolchain";
  enableClangTools = true;
  enableLlvmTools = true;
  enableDocC = true;
  enableSourceKitLSP = true;
  enableSwiftFormat = true;
  enableSwiftPM = true;
}
