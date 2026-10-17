/// One piece of the source video. The export plays segments in order.
class Segment {
  double start;
  double end;

  Segment(this.start, this.end);

  Segment copy() => Segment(start, end);
}

String fmtSec(double s) => '${s.toStringAsFixed(1)}s';
