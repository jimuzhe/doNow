class ApiConfig {
  // TODO: Replace with your actual Zhipu AI (BigModel) API Key
  static const String apiKey = 'ak_1Rz79T3hr8Zm32D34K51p6f45rt1v'; 
  
  static const String baseUrl = 'https://api.longcat.chat/openai/v1/chat/completions';
  static const String model = 'LongCat-Flash-Chat'; // or 'glm-4-flash', etc.

  // XiaoZhi AI Voice Configuration
  // 官方服务器 (api.tenclass.net) - 参考 xiaozhi-client-flutter
  static const String xiaozhiOtaUrl = 'https://api.tenclass.net/xiaozhi/ota/';
  static const String xiaozhiWebsocketUrl = 'wss://api.tenclass.net/xiaozhi/v1/';
  static const String xiaozhiAdminUrl = 'https://xiaozhi.me';
}
