import 'package:Maya/core/constants/colors.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class EnergyPage extends StatefulWidget {
  final Map<String, dynamic> data;

  const EnergyPage({super.key, required this.data});

  @override
  State<EnergyPage> createState() => _EnergyPageState();
}

class _EnergyPageState extends State<EnergyPage> {
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor:AppColors.cardColor,
                    radius: 20,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: AppColors.balckClr),
                      onPressed: () => context.go('/other'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    "Doll Energy",
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                "AI assistant's energy production and usage",
                style: TextStyle(color: Colors.black54, fontSize: 14),
              ),
              const SizedBox(height: 16),

              _energyLevelCard(),
              const SizedBox(height: 10),

              Row(
                children: [
                  _smallInfoCard(
                    "Energy Produced Today",
                    widget.data['today'] ?? "0",
                    Colors.green.shade50,
                    Colors.green,
                    "assets/energyproduct.png",

                  ),
                  const SizedBox(width: 12),
                  _smallInfoCard(
                    "This Week",
                    widget.data['week'] ?? "0",
                    Colors.orange.shade50,
                    Colors.orange,
                    "assets/thisweek.png",

                  ),
                ],
              ),
              const SizedBox(height: 10),

              Row(
                children: [
                  _smallInfoCard(
                    "This Month",
                    widget.data['month'] ?? "0",
                    Colors.blue.shade50,
                    Colors.blue,
                    "assets/thismonth.png",

                  ),
                  const SizedBox(width: 12),
                  _smallInfoCard(
                    "Conversion Efficiency",
                    "${widget.data['efficiency'] ?? "0"}%",
                    Colors.lightBlue.shade50,
                    Colors.lightBlue,
                    "assets/conversion.png",

                  ),
                ],
              ),
              const SizedBox(height: 10), _usageDonutChart(),
              const SizedBox(height: 10),
              _last7DaysTrend(),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------- ENERGY LEVEL Card ----------------
  Widget _energyLevelCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Energy Level",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 14),
        Row(
          children: List.generate(10, (index) {
            return Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                height: 35,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: index < 6
                        ? [
                      Color(0xffF97418),
                      Color(0xffECB48D),
                    ]
                        : [
                      Colors.grey.shade300.withOpacity(0.1),
                      Colors.grey.shade200, // right darker
                    ],
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            );
          }),
        ),

        const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _energyText("Total Credit", "100%"),
              _energyText("Credit Left", "40%"),
              _energyText("Energy Units", "60%"),
            ],
          ),
        ],
      ),
    );
  }

  Widget _energyText(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.black54, fontSize: 12),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _smallInfoCard(
      String title,
      dynamic value,
      Color bgColor,
      Color textColor,
      String imagePath,
      ) {
    return Expanded(
      child: Container(
        height: 80,
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: const Color(0xffF2F3F4),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Image.asset(
                  imagePath,
                  height: 18,
                  width: 18,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xffF59E0B),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),


            Text(
              "$value",
              style: const TextStyle(
                color: Color(0xffF59E0B),
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }



  Widget _usageDonutChart() {
    String selectedFilter = "Today";
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Usage By Feature",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              StatefulBuilder(
                builder: (context, setState) {
                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedFilter,
                        icon: const Icon(Icons.keyboard_arrow_down_rounded),
                        items: const [
                          DropdownMenuItem(
                            value: "Today",
                            child: Text("Today"),
                          ),
                          DropdownMenuItem(
                            value: "Yesterday",
                            child: Text("Yesterday"),
                          ),
                          DropdownMenuItem(
                            value: "This Week",
                            child: Text("This Week"),
                          ),
                          DropdownMenuItem(
                            value: "This Month",
                            child: Text("This Month"),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            selectedFilter = value!;
                          });
                        },
                      ),
                    ),
                  );
                },
              ),
            ],
          ),

          const SizedBox(height: 10),

          // SizedBox(
          //   height: 220,
          //   child: Stack(
          //     alignment: Alignment.center,
          //     children: [
          //       PieChart(
          //         PieChartData(
          //           sectionsSpace: 4,
          //           centerSpaceRadius: 60,
          //           sections: [
          //             PieChartSectionData(
          //               value: 60,
          //               color: const Color(0xff2D79FF),
          //               radius: 55,
          //             ),
          //             PieChartSectionData(
          //               value: 45,
          //               color: const Color(0xff8B0016),
          //               radius: 55,
          //             ),
          //             PieChartSectionData(
          //               value: 25,
          //               color: const Color(0xff1E725D),
          //               radius: 55,
          //             ),
          //             PieChartSectionData(
          //               value: 20,
          //               color: const Color(0xffC08A20),
          //               radius: 55,
          //             ),
          //           ],
          //         ),
          //       ),
          //       const Text(
          //         "150",
          //         style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          //       ),
          //     ],
          //   ),
          // ),
        SizedBox(
          height: 220,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  startDegreeOffset: -90,
                  sectionsSpace: 3,
                  centerSpaceRadius: 70,
                  sections: [
                    PieChartSectionData(
                      value: 25,
                      color: Color(0xffFF9F00),
                      radius: 15,
                      showTitle: false,
                    ),
                    PieChartSectionData(
                      value: 25,
                      color: Color(0xff2D00FF),
                      radius: 15,
                      showTitle: false,
                    ),
                    PieChartSectionData(
                      value: 25,
                      color: Color(0xffC4006F),
                      radius: 15,
                      showTitle: false,
                    ),
                    PieChartSectionData(
                      value: 25,
                      color: Color(0xff8C00FF),
                      radius: 15,
                      showTitle: false,
                    ),
                  ],
                ),
              ),

              // CENTER TEXT
              Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Text(
                    "84%",
                    style: TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    "used",
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
          const SizedBox(height: 20),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: const [
              _LegendDot(
                color: Color(0xff2D79FF),
                text: "AI Generations (60%)",
              ),
              _LegendDot(
                color: Color(0xff8B0016),
                text: "Voice Interactions (45%)",
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: const [
              _LegendDot(
                color: Color(0xff1E725D),
                text: "Reminders & Tasks (25%)",
              ),
              _LegendDot(
                color: Color(0xffC08A20),
                text: "Integrations Sync (20%)",
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _last7DaysTrend() {
    String selectedFilter = "This Week";

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Last 7 Days Trend",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),

              StatefulBuilder(
                builder: (context, setState) {
                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedFilter,
                        icon: const Icon(Icons.keyboard_arrow_down_rounded),
                        items: const [
                          DropdownMenuItem(
                            value: "This Week",
                            child: Text("This Week"),
                          ),
                          DropdownMenuItem(
                            value: "This Month",
                            child: Text("This Month"),
                          ),
                          DropdownMenuItem(
                            value: "This Year",
                            child: Text("This Year"),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            selectedFilter = value!;
                          });
                        },
                      ),
                    ),
                  );
                },
              ),
            ],
          ),

          const Text(
            "Credit Used",
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
          const SizedBox(height: 10),

          Center(
            child: SizedBox(
              height: 200,
              width: 270,
              child: LineChart(
                LineChartData(
                  minX: 0,
                  maxX: 6,
                  minY: 80,
                  maxY: 170,

                  gridData: FlGridData(show: false),
                  borderData: FlBorderData(show: false),

                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 1,
                        getTitlesWidget: (value, _) {
                          List<String> days = [
                            "NOV 13",
                            "NOV 14",
                            "NOV 15",
                            "NOV 16",
                            "NOV 17",
                            "NOV 18",
                            "NOV 19",
                          ];
                          return Padding(
                            padding: const EdgeInsets.all(5.0),
                            child: Text(
                              days[value.toInt()],
                              style: const TextStyle(fontSize: 10),
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                  lineBarsData: [
                    LineChartBarData(
                      isCurved: true,
                      barWidth: 3,
                      color: Colors.orange,
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.orange.withOpacity(0.45),
                            Colors.orange.withOpacity(0.05),
                          ],
                        ),
                      ),
                      dotData: FlDotData(show: true),
                      spots: const [
                        FlSpot(0, 150),
                        FlSpot(1, 120),
                        FlSpot(2, 135),
                        FlSpot(3, 140),
                        FlSpot(4, 130),
                        FlSpot(5, 138),
                        FlSpot(6, 150),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String text;

  const _LegendDot({required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          height: 12,
          width: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(text, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}
