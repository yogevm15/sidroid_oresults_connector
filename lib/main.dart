import 'dart:async';
import 'dart:convert';
import 'package:skeleton_loader/skeleton_loader.dart';
import 'package:Connector/event_preview.dart';
import 'package:android_long_task/android_long_task.dart';
import 'package:timer_count_down/timer_controller.dart';
import 'package:timer_count_down/timer_count_down.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

import 'exceptions.dart';

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
        home: const MyHomePage(title: 'SIDroid OResults Connector'),
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

enum RunningState { running, waiting, stopped }

class _MyHomePageState extends State<MyHomePage> {
  RunningState _running = RunningState.stopped;
  double _intervalValue = 20;
  Timer? _currWorker;
  final _events = LimitedSizeList<Event>(100);
  final _portController = TextEditingController();
  final _apiKeyController = TextEditingController();
  final _eventsListKey = GlobalKey<AnimatedListState>();
  CountdownController _countdownController = CountdownController();
  RunningState _uploading = RunningState.stopped;
  EventApiResponse? _currEventData;
  bool isValidPort = false;

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
        if (serviceDataUpdate.currEvent?.message == "Done timer") {
          _uploading = RunningState.running;
          _eventsListKey.currentState?.insertItem(0);
        } else {
          _countdownController = CountdownController(autoStart: true);
          _uploading = RunningState.waiting;
          if (_events.items.length >= _events.maxSize) {
            _eventsListKey.currentState?.removeItem( _events.maxSize - 1, (context, animation) => const SizedBox.shrink());
          }
          _events.add(serviceDataUpdate.currEvent!);
        }
      });
      //your code
    });
  }

  startUploading() async {
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
      if (_uploading == RunningState.running) {
        _eventsListKey.currentState?.removeItem(0, (context, animation) => const SizedBox.shrink());
      }
      _uploading = RunningState.stopped;
      _running = RunningState.stopped;
      _currEventData = null;
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
            return Row(
              children: <Widget>[
                Expanded(
                    child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      _buildApiKeyTextField(),
                      _buildPortTextField(),
                      _buildSlider(),
                    ],
                  ),
                )),
                Expanded(
                    child: SingleChildScrollView(
                  child: Column(
                    // mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      _buildButton(),
                      _buildEventPreview(),
                      _buildLogTitle(),
                      _buildListView(),
                    ],
                  ),
                )),
              ],
            );
          } else {
            // Portrait mode or small screen
            return SingleChildScrollView(
                child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                _buildApiKeyTextField(),
                _buildPortTextField(),
                _buildSlider(),
                _buildButton(),
                _buildEventPreview(),
                _buildLogTitle(),
                _buildListView(),
              ],
            ));
          }
        },
      ),
    );
  }

  Widget _buildApiKeyTextField() {
    double verticalPadding =
        MediaQuery.of(context).orientation == Orientation.landscape
            ? 8.0
            : 16.0;
    return Padding(
      padding:
          EdgeInsets.symmetric(horizontal: 16.0, vertical: verticalPadding),
      child: TextField(
        textInputAction: TextInputAction.next,
        onChanged: (_) {
          setState(() {});
        },
        enabled: _running == RunningState.stopped,
        controller: _apiKeyController,
        keyboardType: TextInputType.multiline,
        decoration: const InputDecoration(
          border: OutlineInputBorder(),
          labelText: "Enter Api Key",
          hintText: "Enter Api Key",
        ),
      ),
    );
  }

  Widget _buildPortTextField() {
    double verticalPadding =
        MediaQuery.of(context).orientation == Orientation.landscape
            ? 8.0
            : 16.0;
    return Padding(
      padding:
          EdgeInsets.symmetric(horizontal: 16.0, vertical: verticalPadding),
      child: TextField(
        textInputAction: TextInputAction.done,
        onChanged: (_) {
          setState(() {});
        },
        enabled: _running == RunningState.stopped,
        controller: _portController,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(
          border: OutlineInputBorder(),
          labelText: "Enter Port",
          hintText: "Enter Port",
        ),
        inputFormatters: <TextInputFormatter>[
          FilteringTextInputFormatter.digitsOnly,
          NumericalRangeFormatter(min: 0, max: 65535)
        ],
      ),
    );
  }

  Widget _buildSlider() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 8.0, right: 8.0, bottom: 32.0),
            child: Text("Upload interval:"),
          ),
          Slider(
            value: _intervalValue,
            min: 5,
            max: 120,
            divisions: 115,
            label: '${_intervalValue.round()} seconds',
            onChanged: _running == RunningState.running ||
                    _running == RunningState.waiting
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

  Widget _buildEventPreview() {
    return _running == RunningState.waiting
        ? SkeletonLoader(
            builder: ListTile(
              leading: Container(
                height: 38,
                width: 54,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.all(Radius.circular(8)),
                  color: Theme.of(context).primaryColor,
                ),
              ),
              title: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      // alignment: Alignment.bottomLeft,
                      height: 14,
                      width: 75,
                      decoration: BoxDecoration(
                          borderRadius:
                              const BorderRadius.all(Radius.circular(4)),
                          color: Theme.of(context).primaryColor),
                    )
                  ]),
              subtitle: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      // alignment: Alignment.bottomLeft,
                      height: 10,
                      width: 130,
                      decoration: BoxDecoration(
                        borderRadius:
                            const BorderRadius.all(Radius.circular(4)),
                        color: Theme.of(context).primaryColor,
                      ),
                    )
                  ]),
              trailing: Container(
                  width: 70.0,
                  height: 8.0,
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.all(Radius.circular(4)),
                    color: Theme.of(context).primaryColor,
                  )),
            ),
            period: const Duration(seconds: 1),
            direction: SkeletonDirection.ltr,
            highlightColor: Theme.of(context).highlightColor,
          )
        : EventPreview(
            data: _currEventData,
          );
  }

  Widget _buildButton() {
    Widget childWidget;
    switch (_running) {
      case RunningState.stopped:
        childWidget = FilledButton(
          onPressed: _apiKeyController.value.text.isEmpty ||
                  _portController.value.text.isEmpty
              ? null
              : () async {
                  setState(() {
                    _running = RunningState.waiting;
                  });
                  EventApiResponse eventData;
                  try {
                    eventData =
                        await fetchEventData(_apiKeyController.value.text);

                    await upload(int.parse(_portController.value.text),
                        _apiKeyController.value.text);
                  } on BaseError catch (e) {
                    showAlertDialog("Error", e.err);
                    setState(() {
                      _running = RunningState.stopped;
                    });
                    return;
                  }
                  setState(() {
                    _currEventData = eventData;
                    _countdownController = CountdownController(autoStart: true);
                    _uploading = RunningState.waiting;
                    if (_events.items.length >= _events.maxSize) {
                      _eventsListKey.currentState?.removeItem( _events.maxSize - 1, (context, animation) => const SizedBox.shrink());
                    }
                    _events.add(Event("Started, Uploaded", true, DateTime.now()));
                    _eventsListKey.currentState?.insertItem(0);
                    _running = RunningState.running;
                  });
                  startUploading();
                },
          child: const Text("Start uploading"),
        );
      case RunningState.waiting:
        childWidget = const FilledButton(
          onPressed: null,
          child: Text("Stop uploading"),
        );
      case RunningState.running:
        childWidget = FilledButton.tonal(
            onPressed: () {
              stopUploading();
            },
            child: const Text("Stop uploading"));
    }
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: childWidget,
    );
  }

  Widget _buildLogTitle() {
    final Widget timer = _uploading == RunningState.waiting
        ? Countdown(
            build: (BuildContext _, double time) => buildCountdownText(time.toInt()),
            seconds: _intervalValue.toInt(),
            controller: _countdownController,
          )
        : const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 16, left: 32, right: 38),
      child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [const Text("Events log:"), timer]),
    );
  }
  
  Widget buildCountdownText(int seconds) {
    if (seconds==0) {
      return const Text("");
    } else if (seconds % 60 == 0) {
      return Text("${(seconds/60).floor()}m");
    } else if (seconds > 60) {
      return Text("${(seconds/60).floor()}m ${seconds%60}s");
    } else {
      return Text("${seconds}s");
    }
  }
  
  Widget _buildListView() {
    double height = MediaQuery.of(context).orientation == Orientation.landscape
        ? _running == RunningState.stopped ? 170 : 95.0
        : _running == RunningState.stopped ? 310 : 235.0;

    return Container(
        height: height,
        padding: const EdgeInsets.all(16.0),
        child: AnimatedList(
          key: _eventsListKey,
          itemBuilder: (context, index, animation) {
            List<Widget> children = _uploading == RunningState.running
                ? [
              SkeletonLoader(
                builder: ListTile(
                  title: Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          // alignment: Alignment.bottomLeft,
                          height: 14,
                          width: 75,
                          decoration: BoxDecoration(
                              borderRadius:
                              const BorderRadius.all(Radius.circular(4)),
                              color: Theme.of(context).primaryColor),
                        )
                      ]),
                  subtitle: Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          // alignment: Alignment.bottomLeft,
                          height: 10,
                          width: 135,
                          decoration: BoxDecoration(
                            borderRadius:
                            const BorderRadius.all(Radius.circular(4)),
                            color: Theme.of(context).primaryColor,
                          ),
                        )
                      ]),
                  trailing: Container(
                      width: 8.0,
                      height: 8.0,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Theme.of(context).primaryColor,
                      )),
                ),
                period: const Duration(seconds: 1),
                direction: SkeletonDirection.ltr,
                highlightColor: Theme.of(context).highlightColor,
              )
            ]
                : [];
            children.addAll(_events._items.reversed.map((e) => ListTile(
              title: Text(e.message),
              subtitle: Text(
                  "${e.time.year.toString()}-${e.time.month.toString().padLeft(2, '0')}-${e.time.day.toString().padLeft(2, '0')} ${e.time.hour.toString().padLeft(2, '0')}:${e.time.minute.toString().padLeft(2, '0')}:${e.time.second.toString().padLeft(2, '0')}"),
              trailing: Container(
                width: 8.0,
                height: 8.0,
                decoration: BoxDecoration(
                  color: e.success ? Colors.green : Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
            )));
            return SizeTransition(
                sizeFactor: animation, child: children[index]);
          },
        ));
  }

  showAlertDialog(String title, String content) {
    // set up the button
    Widget okButton = TextButton(
      child: const Text("OK"),
      onPressed: () {
        Navigator.of(context).pop();
      },
    );

    // set up the AlertDialog
    AlertDialog alert = AlertDialog(
      icon: const Icon(Icons.warning_amber, color: Colors.redAccent),
      title: Text(
        title,
        textAlign: TextAlign.center,
      ),
      content: Text(
        content,
      ),
      actions: [
        okButton,
      ],
    );

    // show the dialog
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return alert;
      },
    );
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

upload(int port, String apiKey) async {
  Uri url = Uri.http("localhost:$port", "reports/ResultsIof30Xml");
  http.Response response;
  try {
    response = await http.get(url);
  } catch (_) {
    throw SiDroidResultsServiceNotRunning();
  }
  if (response.statusCode != 200) {
    throw FetchResultsFromSiDroidFailed(response.body);
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
    ..fields['apiKey'] = apiKey
    ..files.add(http.MultipartFile.fromString("file", document.toXmlString()));
  try {
    response = await http.Response.fromStream(await request.send());
  } catch (_) {
    throw CouldNotReachOresults();
  }
  if (response.statusCode != 200) {
    throw UploadToEventFailed(response.body);
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
    uploadPeriodic(serviceData);
  });
}

uploadPeriodic(UploadingData serviceData) {
  Timer(Duration(seconds: serviceData.intervalValue), () async {
    ServiceClient.update(serviceData
      ..currEvent =
          serviceData.currEvent = Event("Done timer", true, DateTime.now()));
    try {
      await upload(serviceData.port, serviceData.apiKey);
      ServiceClient.update(
          serviceData..currEvent = Event("Uploaded", true, DateTime.now()));
    } on BaseError catch (e) {
      ServiceClient.update(
          serviceData..currEvent = Event(e.err, false, DateTime.now()));
    } finally {
      uploadPeriodic(serviceData);
    }
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
