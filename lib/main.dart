import 'package:flutter/material.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';

Future<String> getAppVersion() async {
  PackageInfo packageInfo = await PackageInfo.fromPlatform();
  version = packageInfo.version;
  print('version $version ${packageInfo.version}');
  return packageInfo.version; // e.g., "1.0.1"
}

Future<String> getAppDeviceId() async {
  String deviceId = '123'; // Default value
  // Retrieve the current device ID directly
  deviceId = OneSignal.User.pushSubscription.id ?? '123';

  // Optionally, if you want to add a listener for future updates:
  OneSignal.User.pushSubscription.addObserver((state) {
    deviceId = OneSignal.User.pushSubscription.id ?? '123';
    print('Device ID updated: $deviceId');
  });

  return deviceId;
}

void main() {
  runApp(const MyApp());
  initPlatformState();
}

bool _requireConsent = false;
String deviceId = '123'; // Initialize deviceId
String version = ''; // Initialize version
String url =
    'https://weare.skillters.in/parentsside/parent_login?deviceId=$deviceId&version=$version';
// Platform messages are asynchronous, so we initialize in an async method.
Future<void> initPlatformState() async {
  OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
  OneSignal.Debug.setAlertLevel(OSLogLevel.none);
  OneSignal.consentRequired(_requireConsent);

  // NOTE: Replace with your own app ID from https://www.onesignal.com
  OneSignal.initialize("9d720639-6e9a-466a-9c95-be085af75a7f");

  OneSignal.LiveActivities.setupDefault();
  OneSignal.Notifications.clearAll();

  // Add an observer to track the push subscription state
  OneSignal.User.pushSubscription.addObserver((state) {
    print('Push subscription state changed');
    print('Opted in: ${OneSignal.User.pushSubscription.optedIn}');
    print('Subscription ID: ${OneSignal.User.pushSubscription.id}');
    print('Token: ${OneSignal.User.pushSubscription.token}');

    // Update the deviceId with the OneSignal subscription ID
    deviceId = OneSignal.User.pushSubscription.id ?? '123';
  });

  OneSignal.User.addObserver((state) {
    var userState = state.jsonRepresentation();
    print('OneSignal user changed: $userState');
  });

  OneSignal.Notifications.addPermissionObserver((state) {
    print("Has permission: $state");
  });
  // Add notification open handler to handle notification taps
  OneSignal.Notifications.addClickListener((event) {
    print('NOTIFICATION CLICK LISTENER CALLED WITH EVENT: $event');
    navigatorKey.currentState!.push(
      MaterialPageRoute(
        builder: (context) => const MyApp(),
      ),
    );
  });
}

late InAppWebViewController _webViewController;

// Function to explicitly ask for notification permission
Future<void> _askNotificationPermission() async {
  var permissionState = await OneSignal.Notifications.requestPermission(true);
  print('Notification permission state: $permissionState');
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Skillters Educational Portal',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      debugShowCheckedModeBanner: false,
      home: const UrlLauncherPage(),
    );
  }
}

class UrlLauncherPage extends StatefulWidget {
  const UrlLauncherPage({super.key});

  @override
  State<UrlLauncherPage> createState() => _UrlLauncherPageState();
}

class _UrlLauncherPageState extends State<UrlLauncherPage> {
  late InAppWebViewController _webViewController;
  bool canGoBack = false;
  PullToRefreshController? _pullToRefreshController;
  void initHandler() async {
    await getAppVersion();
    await getAppDeviceId();
    print('init device id $deviceId version $version');
  }

  @override
  void initState() {
    super.initState();
    initHandler();
    print('device id $deviceId version $version');
    print(url);

    // Set up OneSignal observer and refresh WebView with deviceId
    OneSignal.User.pushSubscription.addObserver((state) {
      setState(() {
        deviceId = OneSignal.User.pushSubscription.id ?? '123';
      });
      print('Updated deviceId: $deviceId');
      _loadWebPageWithUrl(url);
      checkInternetConnection();
      print('device id $deviceId version $version');
    });

    _pullToRefreshController = PullToRefreshController(
      onRefresh: () async {
        _webViewController.reload(); // Refresh the web view when pulled
      },
    );

    // Ask for notification permission when app starts
    Future.delayed(const Duration(seconds: 4), () {
      _askNotificationPermission();
    });
  }

  void checkInternetConnection() async {
    final List<ConnectivityResult> connectivityResult =
        await (Connectivity().checkConnectivity());

    if (connectivityResult.contains(ConnectivityResult.none)) {
      _showNoInternetDialog();
    }

    Connectivity().onConnectivityChanged.listen((result) {
      if (result == ConnectivityResult.none) {
        _showNoInternetDialog();
      }
    });
  }

  void _showNoInternetDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('No Internet Connection'),
        content: const Text('Please check your internet connection.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (await _webViewController.canGoBack()) {
          _webViewController.goBack();
          return Future.value(false); // Prevent app from closing
        } else {
          return Future.value(true); // Allow app to close
        }
      },
      child: SafeArea(
        child: InAppWebView(
          pullToRefreshController: _pullToRefreshController,
          initialUrlRequest: URLRequest(
            url: WebUri(url), // Initial URL with deviceId
          ),
          onWebViewCreated: (controller) {
            _webViewController = controller;
          },
          onLoadStart: (controller, url) async {
            setState(() {});
          },
          onLoadStop: (controller, url) async {
            bool canGoBackResult = await controller.canGoBack();
            setState(() {
              canGoBack = canGoBackResult;
            });
            _pullToRefreshController
                ?.endRefreshing(); // Stop refreshing after loading completes
          },
          onConsoleMessage: (controller, consoleMessage) {
            print(consoleMessage);
          },
        ),
      ),
    );
  }

  // Function to load the web page with deviceId as a URL parameter
  // void _loadWebPageWithDeviceId() {
  //   _webViewController.loadUrl(
  //     urlRequest: URLRequest(
  //       url: WebUri("https://api.ministudy.in?deviceId=$deviceId"),
  //     ),
  //   );
  // }

  // Function to load the web page with a specific URL (from notification click)
  void _loadWebPageWithUrl(String url) {
    _webViewController.loadUrl(
      urlRequest: URLRequest(
        url: WebUri(url),
      ),
    );
  }
}
