import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:file_previewer/file_previewer.dart';
import 'package:flutter/material.dart';
import 'package:loader_overlay/loader_overlay.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

import 'model.dart';
import 'objectbox.dart';

// ignore_for_file: public_member_api_docs

/// Provides access to the ObjectBox Store throughout the app.
late ObjectBox objectbox;

Future<void> main() async {
  // This is required so ObjectBox can get the application directory
  // to store the database in.
  WidgetsFlutterBinding.ensureInitialized();

  objectbox = await ObjectBox.create();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'OB Example',
        theme: ThemeData(primarySwatch: Colors.blue),
        home: const LoaderOverlay(child: MyHomePage(title: 'OB Example')),
      );
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final _noteInputController = TextEditingController();
  final filePreviewFutures = <Future<Widget>>[];
  final pickedFilePaths = <String>[];

  Future<void> _addNote() async {
    if (_noteInputController.text.isEmpty) return;

    await objectbox.addNote(
      Note(
        _noteInputController.text,
        attachedFilePaths: pickedFilePaths,
      ),
    );
    _noteInputController.text = '';
    filePreviewFutures.clear();
    pickedFilePaths.clear();
    setState(() {

    });
  }

  @override
  void dispose() {
    _noteInputController.dispose();
    super.dispose();
  }

  GestureDetector Function(BuildContext, int) _itemBuilder(List<Note> notes) =>
      (BuildContext context, int index) => GestureDetector(
            onTap: () => objectbox.removeNote(notes[index].id),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Container(
                    decoration: const BoxDecoration(
                        border:
                            Border(bottom: BorderSide(color: Colors.black12))),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 18.0, horizontal: 10.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          if (notes[index].attachedFilePaths.isNotEmpty)
                            Column(
                              children: [
                                SizedBox(
                                  height: 80,
                                  child: ListView.separated(
                                      scrollDirection: Axis.horizontal,
                                      itemCount:
                                          notes[index].attachedFilePaths.length,
                                      separatorBuilder: (context, index) =>
                                          const SizedBox(
                                            width: 12,
                                          ),
                                      itemBuilder: (context, fileIndex) {
                                        return Container(
                                          width: 80,
                                          height: 80,
                                          decoration: BoxDecoration(
                                            border: Border.all(
                                              color: Colors.grey,
                                              width: 1,
                                            ),
                                          ),
                                          child: FutureBuilder(
                                              future: FilePreview.getThumbnail(
                                                  notes[index]
                                                          .attachedFilePaths[
                                                      fileIndex]),
                                              builder: (context, snapshot) {
                                                if (snapshot.hasData) {
                                                  return snapshot.data!;
                                                }

                                                return const CircularProgressIndicator();
                                              }),
                                        );
                                      }),
                                ),
                                const SizedBox(
                                  height: 12,
                                ),
                              ],
                            ),
                          Text(
                            notes[index].text,
                            style: const TextStyle(
                              fontSize: 15.0,
                            ),
                            // Provide a Key for the integration test
                            key: Key('list_item_$index'),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(top: 5.0),
                            child: Text(
                              'Added on ${notes[index].dateFormat}',
                              style: const TextStyle(
                                fontSize: 12.0,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
        ),
        body: Column(children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10.0),
                        child: Column(
                          children: [
                            PickedFileList(
                              filePreviewFutures: filePreviewFutures,
                              pickedFilePaths: pickedFilePaths,
                            ),
                            TextField(
                              decoration: const InputDecoration(
                                hintText: 'Enter a new note',
                              ),
                              controller: _noteInputController,
                              onSubmitted: (value) => _addNote(),
                              // Provide a Key for the integration test
                              key: const Key('input'),
                            ),
                          ],
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.only(top: 10.0, right: 10.0),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            'Tap a note to remove it',
                            style: TextStyle(
                              fontSize: 11.0,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Note>>(
              stream: objectbox.getNotes(),
              builder: (context, snapshot) => ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                itemCount: snapshot.hasData ? snapshot.data!.length : 0,
                itemBuilder: _itemBuilder(
                  snapshot.data ?? [],
                ),
              ),
            ),
          ),
        ]),
        // We need a separate submit button because flutter_driver integration
        // test doesn't support submitting a TextField using "enter" key.
        // See https://github.com/flutter/flutter/issues/9383
        floatingActionButton: FloatingActionButton(
          key: const Key('submit'),
          onPressed: _addNote,
          child: const Icon(Icons.add),
        ),
      );
}

class PickedFileList extends StatefulWidget {
  const PickedFileList({
    super.key,
    required this.filePreviewFutures,
    required this.pickedFilePaths,
  });

  final List<Future<Widget>> filePreviewFutures;
  final List<String> pickedFilePaths;

  @override
  State<PickedFileList> createState() => _PickedFileListState();
}

class _PickedFileListState extends State<PickedFileList> {
  Future<void> pickFiles(BuildContext context) async {
    FilePickerResult? res =
        await FilePicker.platform.pickFiles(allowMultiple: true);

    try {
      if (res == null) return;
      if (!context.mounted) return;

      context.loaderOverlay.show();
      final directory = await getApplicationDocumentsDirectory();
      final dateTime = DateTime.now().toUtc();

      widget.filePreviewFutures.clear();
      widget.pickedFilePaths.clear();

      final copyFileToStorageFutures = <Future<File>>[];

      for (final path in res.paths) {
        if (path != null) {
          final file = File(path);

          final targetPath = join(
            directory.path,
            dateTime.millisecondsSinceEpoch.toString() + basename(path),
          );
          final newFile = File(targetPath);

          debugPrint('cek targetPath : $targetPath');
          copyFileToStorageFutures
              .add(newFile.writeAsBytes(await file.readAsBytes()).then((value) {
            widget.pickedFilePaths.add(value.path);
            return value;
          }));
          widget.filePreviewFutures.add(FilePreview.getThumbnail(path));
        }
      }

      await Future.wait(copyFileToStorageFutures);
      debugPrint(
          'cek filePreviewFutures length : ${widget.filePreviewFutures.length}');
      debugPrint(
          'cek pickedFilePaths length : ${widget.pickedFilePaths.length}');

      if (!context.mounted) return;
      context.loaderOverlay.hide();

      setState(() {});
    } catch (e) {
      if (!context.mounted) return;
      context.loaderOverlay.hide();
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 120,
      child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: widget.filePreviewFutures.length + 1,
          separatorBuilder: (context, index) => const SizedBox(
                width: 12,
              ),
          itemBuilder: (context, index) {
            if (index == widget.filePreviewFutures.length) {
              return InkWell(
                onTap: () {
                  pickFiles(context);
                },
                child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Colors.grey,
                        width: 1,
                      ),
                    ),
                    child: const Center(
                      child: Text(
                        'Pick File',
                        textAlign: TextAlign.center,
                      ),
                    )),
              );
            }

            return Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                border: Border.all(
                  color: Colors.grey,
                  width: 1,
                ),
              ),
              child: FutureBuilder(
                  future: widget.filePreviewFutures[index],
                  builder: (context, snapshot) {
                    if (snapshot.hasData) {
                      return snapshot.data!;
                    }

                    return const CircularProgressIndicator();
                  }),
            );
          }),
    );
  }
}
