import 'dart:async';
import 'dart:convert';
import 'package:android_long_task/android_long_task.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

const _defaultLightColorScheme = ColorScheme.light();

const _defaultDarkColorScheme = ColorScheme.dark();

void main() async {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
        builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'SiDroid-OResults Connector',
        theme: ThemeData(
            useMaterial3: true,
            colorScheme: lightDynamic ?? _defaultLightColorScheme),
        darkTheme: ThemeData(
            useMaterial3: true,
            colorScheme: darkDynamic ?? _defaultDarkColorScheme),
        themeMode: ThemeMode.system,
        home: const MyHomePage(title: 'Connector'),
      );
    });
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  bool _running = false;
  double _intervalValue = 20;
  Timer? _currWorker;
  final _events = LimitedSizeList<Event>(100);
  final _portController = TextEditingController();
  final _apiKeyController = TextEditingController();

  @override
  void initState() {
    super.initState();

    AppClient.updates.listen((json) {
      if (json == null) {
        return;
      }
      var serviceDataUpdate = UploadingData.fromJson(json);
      if (serviceDataUpdate.currEvent == null) {
        return;
      }
      setState(() {
        _events.add(serviceDataUpdate.currEvent!);
      });
      //your code
    });
  }

  startUploading() async {
    setState(() {
      _running = true;
    });
    if (_currWorker != null) {
      return;
    }

    await AppClient.execute(UploadingData(_apiKeyController.value.text,
        _intervalValue.toInt(), int.parse(_portController.value.text), null));
  }

  showMessage(String message) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @pragma('vm:entry-point')
  stopUploading() async {
    _currWorker?.cancel();
    await AppClient.stopService();
    setState(() {
      _running = false;
    });
  }

  @override
  void dispose() {
    // Clean up the controller when the widget is disposed.
    _portController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          if (MediaQuery.of(context).orientation == Orientation.landscape) {
            // Landscape mode or large screen
            return GridView.count(
            crossAxisCount: 2,
            children: <Widget>[
                SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.max,
                    children: <Widget>[
                      _buildTextField(
                          _apiKeyController, 'Enter Api Key', _running),
                      _buildTextField(_portController, 'Enter Port', _running),
                      _buildSlider(),
                    ],
                  ),
                ),
                SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.max,
                    children: <Widget>[
                      _buildButton(),
                      _buildLog(),
                      _buildListView(),
                    ],
                  ),
                ),
              ],
            );
          } else {
            // Portrait mode or small screen
            return SingleChildScrollView(
                child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                _buildTextField(_apiKeyController, 'Enter Api Key', _running),
                _buildTextField(_portController, 'Enter Port', _running),
                _buildSlider(),
                _buildButton(),
                _buildLog(),
                _buildListView(),
              ],
            ));
          }
        },
      ),
    );
  }

  Widget _buildTextField(
      TextEditingController controller, String label, bool running) {
    bool isPortField = controller == _portController;
    double verticalPadding =
        MediaQuery.of(context).orientation == Orientation.landscape
            ? 8.0
            : 16.0;
    return Padding(
      padding:
          EdgeInsets.symmetric(horizontal: 16.0, vertical: verticalPadding),
      child: TextField(
        onChanged: (_) {
          setState(() {});
        },
        enabled: !running,
        controller: controller,
        keyboardType:
            isPortField ? TextInputType.number : TextInputType.multiline,
        decoration: InputDecoration(
          border: const OutlineInputBorder(),
          labelText: label,
          hintText: label,
        ),
        inputFormatters: isPortField
            ? <TextInputFormatter>[
                FilteringTextInputFormatter.digitsOnly,
                NumericalRangeFormatter(min: 0, max: 65535)
              ]
            : [],
        // textCapitalization: MediaQuery.of(context).orientation == Orientation.landscape || MediaQuery.of(context).size.width > 600 ? TextCapitalization.characters : TextCapitalization.none,
      ),
    );
  }

  Widget _buildSlider() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 8.0, right: 8.0, bottom: 32.0),
            child: Text("Upload interval:"),
          ),
          Slider(
            value: _intervalValue,
            min: 1,
            max: 120,
            divisions: 120,
            label: '${_intervalValue.round()} seconds',
            onChanged: _running
                ? null
                : (double value) {
                    setState(() {
                      _intervalValue = value;
                    });
                  },
          )
        ],
      ),
    );
  }

  Widget _buildButton() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: _running
          ? FilledButton.tonal(
              onPressed: stopUploading, child: const Text("Stop uploading"))
          : FilledButton(
              onPressed: _apiKeyController.value.text.isEmpty ||
                      _portController.value.text.isEmpty
                  ? null
                  : startUploading,
              child: const Text("Start uploading"),
            ),
    );
  }

  Widget _buildLog() {
    return Container(
        alignment: AlignmentDirectional.topStart,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
        child: const Text("Events log:"));
  }

  Widget _buildListView() {
    double height =
    MediaQuery.of(context).orientation == Orientation.landscape
        ? 130.0
        : 300.0;
    return Container(
      height: height,
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: _events._items.reversed
              .map((e) => ListTile(
                    title: Text(e.message),
                    subtitle: Text("${e.time.year.toString()}-${e.time.month.toString().padLeft(2,'0')}-${e.time.day.toString().padLeft(2,'0')} ${e.time.hour.toString().padLeft(2,'0')}:${e.time.minute.toString().padLeft(2,'0')}:${e.time.second.toString().padLeft(2,'0')}"),
                    trailing: Container(
                      width: 8.0,
                      height: 8.0,
                      decoration: BoxDecoration(
                        color: e.success ? Colors.green : Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ))
              .toList(),
        ));
  }
}

class Event {
  final String message;
  final bool success;
  final DateTime time;

  Event(this.message, this.success, this.time);

  String toJson() {
    var map = {
      'message': message,
      'success': success,
      'time': time.millisecondsSinceEpoch,
    };
    return jsonEncode(map);
  }

  static Event fromJson(Map<String, dynamic> json) {
    return Event(json['message'] as String, json['success'] as bool,
        DateTime.fromMillisecondsSinceEpoch(json['time'] as int));
  }
}

class LimitedSizeList<T> {
  final int maxSize;
  final List<T> _items = [];

  LimitedSizeList(this.maxSize);

  void add(T item) {
    if (_items.length >= maxSize) {
      _items.removeAt(0); // Remove the oldest item
    }
    _items.add(item);
  }

  List<T> get items => _items.toList();
}

class NumericalRangeFormatter extends TextInputFormatter {
  final int min;
  final int max;

  NumericalRangeFormatter({required this.min, required this.max});

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text == '') {
      return newValue;
    }
    final curr = int.parse(newValue.text);
    if (curr < min) {
      return const TextEditingValue().copyWith(text: min.toString());
    } else {
      return curr > max
          ? oldValue
          : newValue.replaced(
              TextRange(start: 0, end: newValue.text.length), curr.toString());
    }
  }
}

upload(UploadingData data) async {
  String url = "http://localhost:${data.port}/reports/ResultsIof30Xml";
  try {
    var response = await http.get(Uri.parse(url));
    if (response.statusCode != 200) {
      ServiceClient.update(data
        ..currEvent = Event(
            "Error, received ${response.statusCode} from SiDroid result service",
            false,
            DateTime.now()));
      return;
    }
    final document = XmlDocument.parse(response.body);
    var id = 1;
    for (XmlElement element in document.findAllElements('Person')) {
      final idElement = element.getElement('Id');
      if (idElement == null) {
        element.children.add(XmlElement(XmlName("Id"), [], [XmlText("$id")]));
      } else {
        idElement.replace(XmlElement(XmlName("Id"), [], [XmlText("$id")]));
      }
      id++;
    }

    var uri = Uri.https('api.oresults.eu', 'results');
    var request = http.MultipartRequest('POST', uri)
      ..fields['apiKey'] = data.apiKey
      ..files
          .add(http.MultipartFile.fromString("file", document.toXmlString()));
    try {
      var oResultResponse = await request.send();
      ServiceClient.update(data
        ..currEvent = oResultResponse.statusCode != 200
            ? Event(
                "Error, received ${oResultResponse.statusCode} from OResults",
                false,
                DateTime.now())
            : Event("Uploaded", true, DateTime.now()));
    } catch (e) {
      ServiceClient.update(data
        ..currEvent = Event(
            "Error, OResults connection refused!", false, DateTime.now()));
    }
  } catch (e) {
    ServiceClient.update(data
      ..currEvent = Event(
          "Error, SiDroid result service not running!", false, DateTime.now()));
  }
}

//this entire function runs in your ForegroundService
@pragma('vm:entry-point')
serviceMain() async {
  //make sure you add this
  WidgetsFlutterBinding.ensureInitialized();
  //if your use dependency injection you initialize them here
  //what ever dart objects you created in your app main function is not  accessible here

  //set a callback and define the code you want to execute when your  ForegroundService runs
  ServiceClient.setExecutionCallback((initialData) async {
    //you set initialData when you are calling AppClient.execute()
    //from your flutter application code and receive it here
    var serviceData = UploadingData.fromJson(initialData);
    Timer.periodic(Duration(seconds: serviceData.intervalValue),
        (_) => upload(serviceData));
  });
}

class UploadingData extends ServiceData {
  final int intervalValue;
  final int port;
  final String apiKey;
  Event? currEvent;

  UploadingData(this.apiKey, this.intervalValue, this.port, this.currEvent);

  @override
  String get notificationTitle => "Uploading Results";

  @override
  String get notificationDescription => "Every $intervalValue seconds";

  @override
  String toJson() {
    var map = {
      'intervalValue': intervalValue,
      'port': port,
      'apiKey': apiKey,
      'event': currEvent?.toJson(),
    };
    return jsonEncode(map);
  }

  static UploadingData fromJson(Map<String, dynamic> json) {
    return UploadingData(
        json['apiKey'] as String,
        json['intervalValue'] as int,
        json['port'] as int,
        json['event'] == null
            ? null
            : Event.fromJson(jsonDecode(json['event'])));
  }
}
