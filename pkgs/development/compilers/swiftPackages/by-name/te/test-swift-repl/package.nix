{
  runCommand,
  swift,
}:

runCommand "test-swift-repl"
  {
    nativeBuildInputs = [ swift ];
    sandboxProfile = ''
      (allow file-read (literal "/Applications/Xcode.app/Contents/SharedFrameworks/LLDB.framework/Resources/debugserver"))
    '';
  }
  ''
    export LLDB_DEBUGSERVER_PATH=/Applications/Xcode.app/Contents/SharedFrameworks/LLDB.framework/Resources/debugserver
    cat <<EOF | swift repl | grep "Saying: Hello, NixpkgsQ!"
      func say(message: String) {
        print("Saying: \(message)")
      }
      say(message: "Hello, Nixpkgs!")
    EOF
    touch "$out"
  ''
