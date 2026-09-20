# Extracts get_it registrations from lib/core/di/injection.dart.
# Emits "<kind>\t<type>" per registration, handling all three call shapes:
#   sl.registerLazySingleton<Iface>(() => Impl(...));
#   sl.registerLazySingleton(() => Foo(...));
#   sl.registerFactory(
#     () => FooCubit(...),
#   );
{
  if (match($0, /register(LazySingleton|Factory)<([^>]+)>/, m)) {
    print m[1] "\t" m[2]; pending = ""; next
  }
  if (match($0, /register(LazySingleton|Factory)\(/, m)) {
    kind = m[1]
    rest = substr($0, RSTART + RLENGTH)
    if (match(rest, /\(\) *=> *([A-Za-z0-9_]+)/, t)) { print kind "\t" t[1]; pending = "" }
    else { pending = kind }
    next
  }
  if (pending != "" && match($0, /\(\) *=> *([A-Za-z0-9_]+)/, t)) {
    print pending "\t" t[1]; pending = ""
  }
}
