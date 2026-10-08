{
  lib,
  sqlite,
  runCommand,
}:

runCommand "CSQLite3-${lib.getVersion sqlite}" { propagatedBuildInputs = [ sqlite ]; } ''
  mkdir -p "$out/include"
  cat <<EOF > "$out/include/SQLite3.modulemap"
  module SQLite3 {
    header "${lib.getInclude sqlite}/include/sqlite3.h"
    export *
    explicit module Ext {
      header "${lib.getInclude sqlite}/include/sqlite3ext.h"
      export *
    }
    link "sqlite3"
  }
  EOF
''
