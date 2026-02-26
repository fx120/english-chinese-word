import '../models/daily_record.dart';

class ContinuousDaysCalculator {
  /// 计算连续学习天数
  /// [dailyRecords] 每日学习记录(按日期降序)
  /// 返回连续天数
  static int calculateContinuousDays(List<DailyRecord> dailyRecords) {
    if (dailyRecords.isEmpty) return 0;
    
    // 按日期降序排序
    dailyRecords.sort((a, b) => b.date.compareTo(a.date));
    
    DateTime today = DateTime.now();
    String todayStr = _formatDate(today);
    String yesterdayStr = _formatDate(today.subtract(const Duration(days: 1)));
    
    // 检查今天或昨天是否有学习记录
    if (dailyRecords[0].date != todayStr && 
        dailyRecords[0].date != yesterdayStr) {
      return 0; // 连续记录已中断
    }
    
    int continuousDays = 0;
    DateTime expectedDate = today;
    
    for (var record in dailyRecords) {
      String expectedDateStr = _formatDate(expectedDate);
      
      if (record.date == expectedDateStr) {
        continuousDays++;
        expectedDate = expectedDate.subtract(const Duration(days: 1));
      } else {
        break; // 连续记录中断
      }
    }
    
    return continuousDays;
  }
  
  static String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
