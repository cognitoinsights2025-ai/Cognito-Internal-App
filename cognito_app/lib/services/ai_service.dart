import 'dart:math';

/// Cognito AI Service — Simulates AI-powered business insights
/// In production, this would connect to a real AI/ML backend
class AiService {
  static final AiService _instance = AiService._internal();
  factory AiService() => _instance;
  AiService._internal();

  final _random = Random();

  /// Generates a contextual AI response based on user query
  Future<String> getResponse(String query) async {
    // Simulate network delay
    await Future.delayed(Duration(milliseconds: 800 + _random.nextInt(1200)));

    final q = query.toLowerCase();

    if (q.contains('revenue') || q.contains('money') || q.contains('sales')) {
      return '📊 **Revenue Analysis:** Current month revenue stands at '
          '**\$2.84M**, up 12.5% from the previous month. The Southeast '
          'region is your strongest performer with 34% of total revenue. '
          'I recommend increasing marketing spend there by 15% for optimal ROI.';
    }

    if (q.contains('user') || q.contains('engagement') || q.contains('active')) {
      return '👥 **User Engagement Report:** Active users grew to **24.8K** '
          'this week. Session duration averages 8.4 minutes (+18%). The new '
          'onboarding flow shows a 23% improvement in Day-1 retention. '
          'Consider A/B testing the checkout funnel next.';
    }

    if (q.contains('report') || q.contains('weekly') || q.contains('summary')) {
      return '📋 **Weekly Report Generated:** Key highlights — Revenue +12.5%, '
          'Active Users +8.2%, Conversion Rate 4.7%. Three anomalies detected '
          'in the payment pipeline that need attention. Shall I email the '
          'full report to your team?';
    }

    if (q.contains('forecast') || q.contains('predict') || q.contains('future')) {
      return '🔮 **Revenue Forecast:** Based on current trajectory, Q2 2026 '
          'is projected at **\$8.2M** (±5%). Strong signals in the enterprise '
          'segment could push this 10% higher if we accelerate outbound sales.';
    }

    if (q.contains('anomal') || q.contains('alert') || q.contains('issue')) {
      return '⚠️ **Anomaly Detected:** 3 unusual patterns found — '
          '1) Payment failures spiked 240% on Apr 24, '
          '2) User signups from Asia dropped 32% yesterday, '
          '3) API response times increased 45ms. '
          'Shall I investigate any of these further?';
    }

    if (q.contains('team') || q.contains('performance') || q.contains('kpi')) {
      return '👨‍💼 **Team Performance:** Your engineering team shipped 23 '
          'features this sprint (velocity +15%). The data science team has '
          '4 models in production with 97.2% accuracy. Marketing generated '
          '1,240 qualified leads this week.';
    }

    if (q.contains('hello') || q.contains('hi') || q.contains('hey')) {
      return '👋 Hello! I\'m Cognito AI, your business intelligence assistant. '
          'I can help with revenue trends, user engagement metrics, forecasting, '
          'and generating reports. What insights are you looking for today?';
    }

    return 'I\'ve analyzed your query about "$query". Based on current data, '
        'I see interesting patterns I\'d like to share. Would you like me to '
        'generate a detailed analysis report, or focus on a specific metric '
        'like revenue, engagement, or conversion?';
  }

  /// Returns a list of AI-generated quick insights
  List<Map<String, String>> getQuickInsights() {
    return [
      {
        'title': 'Revenue Spike Detected',
        'body': 'Revenue trending 23% above forecast. Consider scaling ad spend in the Southeast region.',
        'type': 'positive',
      },
      {
        'title': 'Churn Risk Alert',
        'body': '47 enterprise accounts showing disengagement signals. Reach out within 48 hours.',
        'type': 'warning',
      },
      {
        'title': 'Growth Opportunity',
        'body': 'APAC market shows 3.2x higher conversion on mobile. Optimize mobile funnel.',
        'type': 'info',
      },
    ];
  }

  /// Suggested chat prompts
  List<String> getSuggestions() {
    return [
      '📊 Revenue trends',
      '👥 User engagement',
      '📋 Weekly report',
      '🔮 Forecast Q2',
      '⚠️ Anomalies',
    ];
  }
}
