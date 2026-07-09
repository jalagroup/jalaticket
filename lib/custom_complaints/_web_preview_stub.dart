// Non-web stub — all operations are no-ops; platform uses url_launcher instead
void registerIframeView(String viewId, String url) {}
void downloadFileWeb(String url, String fileName) {}
Future<String> createBlobUrl(String fileUrl) async => fileUrl;
void revokeBlobUrl(String blobUrl) {}
Future<String> fetchText(String fileUrl) async => '';
