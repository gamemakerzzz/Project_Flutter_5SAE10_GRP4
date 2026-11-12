class CourseProgress {
  const CourseProgress(this.name, this.caption, this.progress, this.symbol);
  final String name, caption;
  final double progress;
  final int symbol;
}

class UpcomingExam {
  const UpcomingExam(this.title, this.subject, this.days);
  final String title, subject;
  final int days;
  DateTime dateFrom(DateTime today) =>
      DateTime(today.year, today.month, today.day + days);
}
