/// Not a browser: there is no download to start.
Future<void> downloadTextFile(String fileName, String text, {String mimeType = 'application/json'}) async =>
    throw UnsupportedError('Downloading files is only available in the browser.');
