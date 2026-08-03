import 'package:mynt_plus/api/journal_notes_api.dart';
import 'package:mynt_plus/api/ledger_api.dart';
import '../api_key_generate_api.dart';
import '../auth_api.dart';
import '../banner_api.dart';
import '../bond_api.dart';
import '../change_password_api.dart';
import '../fund_api.dart';
import '../index_api.dart';
import '../ipo_api.dart';
import '../mock_apis/mock_api_response.dart';
import '../market_watch_api.dart';
import '../mutual_fund_api.dart';
import '../notification_api.dart';
import '../order_api.dart';
import '../portfolio_api.dart';
import '../profile_all_details_api.dart';
import '../rupeecase_api.dart';
import '../stock_scanner_api.dart';
import '../stocks_api.dart';
import '../transcation_api.dart';
import '../user_profile_api.dart';
import '../version_api.dart';
import 'api_core.dart';

class ApiExporter
    with
        ApiCore,
        AuthApi,
        BannerApi,
        ChangePasswordApi,
        IndexApi,
        MarketWatchApi,
        PortfolioAPI,
        FundApi,
        NotificationApi,
        BondsApi,
        OrderAPI,
        StocksAPI,
        UserProfileAPI,
        GenerateApiKey,
        IPOApi,
        MutualFundApi,
        TranscationApi,
        MockApiResponse,
        LedgerApi,
        ProfileAllDetailsApi,
        VersionApi,
        StockScannerApi,
        RupeeCaseApi,
        JournalNotesApi {}