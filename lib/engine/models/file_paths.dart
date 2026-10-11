/// The file name at the end of [path], whichever separator it uses (a request
/// saved on Windows can be sent from anywhere). Empty when [path] is empty or
/// ends in a separator.
String fileBaseName(String path) => path.split(RegExp(r'[/\\]')).last;
