import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
 
import '../../../models/order_book_model/order_book_model.dart';
import '../../../provider/thems.dart';
import '../../../provider/websocket_provider.dart';
import '../../../res/global_font_web.dart';
import '../../../res/res.dart';

class OrderScreenHeaderWeb extends ConsumerWidget {
  final OrderScreenArgs headerData;
  
  const OrderScreenHeaderWeb({
    super.key, 
    required this.headerData,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(themeProvider);
    // Watch websocket provider to get current socket data immediately
    final wsProvider = ref.watch(websocketProvider);

    // Get current socket data FIRST (not just from stream)
    // This ensures we show LTP immediately on load, not just after stream emits
    final currentSocketData = wsProvider.socketDatas[headerData.token];

    // PERFORMANCE FIX: Use ref.read() for stream access
    return StreamBuilder<Map>(
      stream: ref.read(websocketProvider).socketDataStream,
      builder: (context, snapshot) {
        // Prefer stream data if available, otherwise use current socket data
        final socketDatas = snapshot.data ?? wsProvider.socketDatas;

        // Update header data with real-time values
        if (socketDatas.containsKey(headerData.token)) {
          final lp = socketDatas[headerData.token]['lp']?.toString();
          final pc = socketDatas[headerData.token]['pc']?.toString();

          if (lp != null && lp != "null" && lp != "" &&
              lp != "0" && lp != "0.0" && lp != "0.00") {
            headerData.ltp = lp;
          }

          if (pc != null && pc != "null" && pc != "" &&
              pc != "0" && pc != "0.0" && pc != "0.00") {
            headerData.perChange = pc;
          }
        }

        // **FIX: Also check current socket data if headerData.ltp is still empty/zero**
        String ltp = headerData.ltp ?? "0.00";
        String perChange = headerData.perChange ?? "0.00";

        // If LTP is still 0 or empty, try to get from current socket data
        if ((ltp.isEmpty || ltp == "0" || ltp == "0.00") && currentSocketData != null) {
          final socketLtp = currentSocketData['lp']?.toString();
          final socketPc = currentSocketData['pc']?.toString();
          if (socketLtp != null && socketLtp != "null" && socketLtp != "0" && socketLtp != "0.00") {
            ltp = socketLtp;
          }
          if (socketPc != null && socketPc != "null") {
            perChange = socketPc;
          }
        }
        
        // Determine color for percentage change
        Color percentageColor = theme.isDarkMode ? colors.textSecondaryDark : colors.textSecondaryLight;
        if (perChange.isNotEmpty) {
          if (perChange.startsWith("-")) {
            percentageColor = theme.isDarkMode ? colors.lossDark : colors.lossLight;
          } else if (perChange != "0.00") {
            percentageColor = theme.isDarkMode ? colors.profitDark : colors.profitLight;
          }
        }
        
        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              "$ltp ",
              style: WebTextStyles.sub(
                isDarkTheme: theme.isDarkMode,
                color: percentageColor,
                fontWeight: WebFonts.medium,
              ),
            ),
            Text(
              " ($perChange%)",
              style: WebTextStyles.sub(
                isDarkTheme: theme.isDarkMode,
                color: theme.isDarkMode ? colors.textSecondaryDark : colors.textSecondaryLight,
                fontWeight: WebFonts.medium,
              ),
            ),
          ],
        );
      }
    );
  }
}
