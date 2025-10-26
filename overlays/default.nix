final: prev: {
  myHello = final.callPackage ../pkgs/hello {};
  myCowsay = final.callPackage ../pkgs/cowsay {};
}
