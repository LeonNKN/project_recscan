import 'package:flutter/material.dart';
import 'package:recscan/widgets/bar_chart_widget.dart'; // Update with the correct relative path

class VisualizationPage2 extends StatelessWidget {
  const VisualizationPage2({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Sample data for the chart.
    final List<String> xAxisList = ['Jan', 'Feb', 'Mar', 'Apr', 'May'];
    final List<double> yAxisList = [30, 45, 25, 60, 50];
    final String xAxisName = "Months";
    final String yAxisName = "Sales";
    final double interval = 10; // adjust as needed

    return Scaffold(
      appBar: AppBar(
        title: const Text("Bar Chart Visualization"),
      ),
      body: Center(
        // Instantiate your SimpleBarChart widget.
        child: SimpleBarChart(
          xAxisList: xAxisList,
          yAxisList: yAxisList,
          xAxisName: xAxisName,
          yAxisName: yAxisName,
          interval: interval,
        ),
      ),
    );
  }
}
