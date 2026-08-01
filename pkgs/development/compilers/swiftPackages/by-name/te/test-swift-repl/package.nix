{
  runCommand,
  swift,
}:

runCommand "test-swift-repl"
  {
    nativeBuildInputs = [ swift ];
  }
  ''
    swift repl <<EOF | grep "Saying: Hello, Nixpkgs!"
      func say(message: String) { print("Saying: \(message)") }
      say(message: "Hello, Nixpkgs!")
    EOF
    touch "$out"
  ''
