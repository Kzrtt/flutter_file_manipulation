import 'dart:io';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_file_manipulation/buttonWithIcon.dart';
import 'package:flutter_file_manipulation/constants.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:video_compress/video_compress.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  File? _image;
  File? _video;
  PlatformFile? file;
  List<PlatformFile> files = [];
  int imageCount = 1;
  int fileCount = 1;
  int audioCount = 1;
  int videoCount = 1;
  String status = "";
  final audioRecord = AudioRecorder();

  //? Gravação do Áudio
  Future<String> getAudioDirectoryPath() async {
    final Directory appDocDir = await getApplicationDocumentsDirectory(); // Isso fornece um diretório que você pode usar
    final Directory audioDir = Directory('${appDocDir.path}/Audios');

    if (!await audioDir.exists()) {
      await audioDir.create(recursive: true); // Cria o diretório se não existir
    }

    return audioDir.path; // Retorna o caminho para o diretório 'Audios'
  }

  Future<void> startRecording() async {
    //await requestPermissions();
    final String audioDirectoryPath = await getAudioDirectoryPath();
    final String audioFilePath = '$audioDirectoryPath/audio.m4a';

    Directory directory = Directory(audioDirectoryPath);
    if (!await directory.exists()) {
      await directory.create(recursive: true); // Cria o diretório se não existir
    }

    if (await audioRecord.hasPermission()) {
      await audioRecord.start(const RecordConfig(), path: audioFilePath);
      print("Recording started at $audioFilePath");
    } else {
      print("Recording permission denied.");
    }
  }

  // Função para parar a gravação
  Future<void> stopRecording() async {
    final path = await audioRecord.stop();
    print("Recording stopped!");
    print("@@@@@@@@@@@@ $path @@@@@@@@@@@");
    _uploadAudio(path!);
  }

  //? upload de um audio
  Future<void> _uploadAudio(String path) async {
    var dio = Dio();

    var formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(path, filename: "audio$audioCount.m4a"),
      'type': 'audio',
    });

    try {
      var response = await dio.post(
        Constants.apiUrl,
        data: formData,
      );
      if (response.statusCode == 200) {
        print('Image uploaded successfully');
        print('---- Debug Mode: RESPONSE ----');
        print(response);
        print('------------------------------');
        setState(() {
          audioCount++;
        });
      } else {
        print('Failed to upload image: ${response.statusCode}');
      }
    } catch (e) {
      print(e);
    }
  }

  //? upload de um audio
  Future<void> _uploadVideo(String path) async {
    var dio = Dio();

    String? compressedPath = await compressVideo(path);

    var formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(compressedPath!, filename: "video$videoCount.mp4"),
      'type': 'video',
    });

    try {
      var response = await dio.post(
        Constants.apiUrl,
        data: formData,
      );
      if (response.statusCode == 200) {
        print('Image uploaded successfully');
        print('---- Debug Mode: RESPONSE ----');
        print(response);
        print('------------------------------');
        setState(() {
          audioCount++;
        });
      } else {
        print('Failed to upload image: ${response.statusCode}');
      }
    } catch (e) {
      print(e);
    }
  }

  //? Upload de multiplos arquivos que estejam localizados na pasta files
  Future<void> _uploadMultiple() async {
    List<PlatformFile> filesCopy = List.from(files);

    for (var element in filesCopy) {
      String? type = element.extension;
      if (['pdf', 'docx', 'xlsx'].contains(type)) {
        file = element;
      } else if (['jpg', 'jpeg', 'png', 'PNG'].contains(type)) {
        _image = File(element.path!);
      } else if (['mp4'].contains(type)) {
        _video = File(element.path!);
      }

      await _upload(
        type == 'pdf'
            ? 'file'
            : type == 'mp4'
                ? 'video'
                : 'image',
      );
      setState(() {
        files.remove(element);
      });
    }

    setState(() {
      files.clear();
    });
  }

  //? upload de um arquivo unico, verificando a variavel image e file
  Future<void> _upload(String type) async {
    if (type == "image" && _image == null) return;
    if (type == 'file' && file == null) return;
    if (type == 'video' && _video == null) return;

    String? compressedVideo = "";
    if (type == 'video') {
      compressedVideo = await compressVideo(_video!.path);
    }

    var dio = Dio();
    var formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        type == 'image'
            ? _image!.path
            : type == 'video'
                ? compressedVideo!
                : file!.path!,
        filename: type == 'image'
            ? 'image$imageCount.jpg'
            : type == 'video'
                ? 'video$videoCount.mp4'
                : 'file$fileCount.pdf',
      ),
      'type': type,
    });

    try {
      var response = await dio.post(
        Constants.apiUrl,
        data: formData,
      );
      if (response.statusCode == 200) {
        print('Image uploaded successfully');
        print('---- Debug Mode: RESPONSE ----');
        print(response);
        print('------------------------------');
        file = null;
        _image = null;
        setState(() {
          status = response.data;
          if (type == 'image') {
            imageCount++;
          } else if (type == 'file') {
            fileCount++;
          } else {
            videoCount++;
          }
        });
      } else {
        print('Failed to upload image: ${response.statusCode}');
      }
    } catch (e) {
      print(e);
    }
  }

  Future<void> pickMany() async {
    final pickedList = await ImagePicker().pickMultipleMedia();

    for (var element in pickedList) {
      PlatformFile file = PlatformFile(
        name: element.name,
        path: element.path,
        size: await element.length(),
        bytes: await element.readAsBytes(),
        readStream: element.openRead(),
      );

      setState(() {
        files.add(file);
      });
    }
  }

  Future<void> pickVideoFromGalery() async {
    final pickedVideo = await ImagePicker().pickVideo(source: ImageSource.gallery);
    PlatformFile file = PlatformFile(
      name: pickedVideo!.name,
      path: pickedVideo.path,
      size: await pickedVideo.length(),
      bytes: await pickedVideo.readAsBytes(),
      readStream: pickedVideo.openRead(),
    );

    setState(() {
      _video = File(pickedVideo.path);
      files.add(file);
    });
  }

  Future<String?> compressVideo(String path) async {
    final MediaInfo? compressedVideo = await VideoCompress.compressVideo(
      path,
      quality: VideoQuality.LowQuality,
      deleteOrigin: false, // True if you want to delete the original video
    );
    if (compressedVideo != null) {
      return compressedVideo.path!;
      // You can now handle the compressed video file
    }
  }

  Future<void> takeVideo() async {
    final pickedVideo = await ImagePicker().pickVideo(source: ImageSource.camera);
    PlatformFile file = PlatformFile(
      name: pickedVideo!.name,
      path: pickedVideo.path,
      size: await pickedVideo.length(),
      bytes: await pickedVideo.readAsBytes(),
      readStream: pickedVideo.openRead(),
    );

    setState(() {
      _video = File(pickedVideo.path);
      files.add(file);
    });
  }

  //? Abrindo a camera e tirando foto
  Future<void> takePicture() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.camera);
    PlatformFile file = PlatformFile(
      name: pickedFile!.name,
      path: pickedFile.path,
      size: await pickedFile.length(),
      bytes: await pickedFile.readAsBytes(),
      readStream: pickedFile.openRead(),
    );

    setState(() {
      _image = File(pickedFile.path);
      files.add(file);
    });
  }

  //? escolhendo foto da galeria
  Future<void> pickImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    PlatformFile file = PlatformFile(
      name: pickedFile!.name,
      path: pickedFile.path,
      size: await pickedFile.length(),
      bytes: await pickedFile.readAsBytes(),
      readStream: pickedFile.openRead(),
    );

    setState(() {
      _image = File(pickedFile.path);
      files.add(file);
    });
  }

  //? Selecionando multiplos arquivos de extensões filtradas
  Future<void> pickMultipleFileFiltered() async {
    FilePickerResult? res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'docx', 'xlsx'],
      allowMultiple: true,
    );

    if (res != null) {
      files = res.files;
      int count = 0;
      for (PlatformFile file in files) {
        print("\n\n");
        print("================ Picked File $count Info ================");
        print("FileName: ${file.name}");
        print("FileBytes: ${file.bytes} bytes");
        print("FileSize: ${file.size}");
        print("FileExtension: ${file.extension}");
        print("FilePath: ${file.path}");
        print("==================================================");
        count++;
      }
    } else {
      print("@ Picker Canceled @");
    }
  }

  //? Pegando muitos arquivos
  Future<void> pickMultipleFile() async {
    FilePickerResult? res = await FilePicker.platform.pickFiles(
      allowMultiple: true,
    );

    if (res != null) {
      files = res.files;
      int count = 0;
      for (PlatformFile file in files) {
        print("\n\n");
        print("================ Picked File $count Info ================");
        print("FileName: ${file.name}");
        print("FileBytes: ${file.bytes} bytes");
        print("FileSize: ${file.size}");
        print("FileExtension: ${file.extension}");
        print("FilePath: ${file.path}");
        print("==================================================");
        count++;
      }
    } else {
      print("@ Picker Canceled @");
    }
  }

  //? Selecionando um arquivo filtrando as extensões
  pickFileFiltered() async {
    FilePickerResult? res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'docx', 'xlsx'],
    );

    if (res != null) {
      file = res.files.first;
      print("\n\n");
      print("================ Picked File Info ================");
      print("FileName: ${file!.name}");
      print("FileBytes: ${file!.bytes} bytes");
      print("FileSize: ${file!.size}");
      print("FileExtension: ${file!.extension}");
      print("FilePath: ${file!.path}");
      print("==================================================");
      setState(() {
        files.add(file!);
      });
    } else {
      print("@ Picker Canceled @");
    }
  }

  //? Selecionando um arquivo sem filtrar a extensão
  pickFile() async {
    FilePickerResult? res = await FilePicker.platform.pickFiles();

    if (res != null) {
      file = res.files.first;
      print("\n\n");
      print("================ Picked File Info ================");
      print("FileName: ${file!.name}");
      print("FileBytes: ${file!.bytes} bytes");
      print("FileSize: ${file!.size}");
      print("FileExtension: ${file!.extension}");
      print("FilePath: ${file!.path}");
      print("==================================================");
      setState(() {
        files.add(file!);
      });
    } else {
      print("@ Picker Canceled @");
    }
  }

  Widget buildFileList(BoxConstraints constraints, List<PlatformFile> files) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 35),
          child: Text(
            "Arquivos em espera: ",
            style: TextStyle(
              color: Colors.purple.withOpacity(.5),
              fontWeight: FontWeight.w600,
              fontSize: 18,
            ),
          ),
        ),
        const SizedBox(height: 20),
        files.isNotEmpty
            ? Wrap(
                children: [
                  SizedBox(
                    width: constraints.maxWidth,
                    child: Column(
                      children: List.generate(
                        files.length,
                        (index) {
                          PlatformFile file = files[index];
                          return Column(
                            children: [
                              InkWell(
                                onTap: () {
                                  if (file.extension == 'pdf') {
                                    file = file;
                                    files.remove(file);
                                    _upload('file');
                                  } else if (file.extension == 'mp4') {
                                    files.remove(file);
                                    _uploadVideo(file.path!);
                                  } else {
                                    _image = File(file.path!);
                                    files.remove(file);
                                    _upload('image');
                                  }
                                },
                                child: Container(
                                  height: 50,
                                  width: constraints.maxWidth * .8,
                                  decoration: BoxDecoration(
                                    borderRadius: const BorderRadius.all(
                                      Radius.circular(10),
                                    ),
                                    color: Colors.purple.withOpacity(.5),
                                  ),
                                  child: Row(
                                    children: [
                                      const SizedBox(width: 10),
                                      Icon(
                                        file.extension == 'pdf'
                                            ? Icons.picture_as_pdf
                                            : file.extension == 'mp4'
                                                ? Icons.videocam
                                                : Icons.image,
                                        color: Colors.purple,
                                      ),
                                      const SizedBox(width: 15),
                                      SizedBox(
                                        width: (constraints.maxWidth * .8) - 70,
                                        child: Text(
                                          file.name,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.purple,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 20),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ],
              )
            : Container(
                height: 50,
                width: constraints.maxWidth * .8,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.all(
                    Radius.circular(10),
                  ),
                  color: Colors.purple.withOpacity(.5),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 10),
                    const Icon(
                      Icons.filter_none,
                      color: Colors.purple,
                    ),
                    const SizedBox(width: 15),
                    SizedBox(
                      width: (constraints.maxWidth * .8) - 70,
                      child: const Text(
                        "Sem Arquivos...",
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.purple,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(width: 20),
                  ],
                ),
              ),
      ],
    );
  }

  @override
  void dispose() {
    // TODO: implement dispose
    audioRecord.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Scaffold(
            body: SizedBox(
              height: constraints.maxHeight,
              width: constraints.maxWidth,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 20),
                    Container(
                      height: 300,
                      width: constraints.maxWidth * .8,
                      decoration: const BoxDecoration(
                        borderRadius: BorderRadius.all(
                          Radius.circular(10),
                        ),
                        color: Colors.grey,
                      ),
                      child: _image == null
                          ? const Center()
                          : Image.file(
                              _image!,
                              fit: BoxFit.cover,
                            ),
                    ),
                    const SizedBox(height: 30),
                    const Divider(indent: 50, endIndent: 50),
                    const SizedBox(height: 20),
                    buildFileList(constraints, files),
                    const SizedBox(height: 10),
                    files.isNotEmpty
                        ? ButtonWithIcon(
                            buttonText: "Upload All",
                            height: 50,
                            width: constraints.maxWidth * .8,
                            borderRadius: 10,
                            onTap: () => _uploadMultiple(),
                            icon: Icons.cloud_upload,
                          )
                        : const Center(),
                    const SizedBox(height: 10),
                    const SizedBox(height: 20),
                    const Divider(indent: 50, endIndent: 50),
                    const SizedBox(height: 15),
                    Text(
                      "File Count: ${fileCount - 1}",
                      style: TextStyle(
                        color: Colors.purple.withOpacity(.5),
                        fontWeight: FontWeight.w600,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      "ImageCount: ${imageCount - 1}",
                      style: TextStyle(
                        color: Colors.purple.withOpacity(.5),
                        fontWeight: FontWeight.w600,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      "audioCount: ${audioCount - 1}",
                      style: TextStyle(
                        color: Colors.purple.withOpacity(.5),
                        fontWeight: FontWeight.w600,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      "videoCount: ${videoCount - 1}",
                      style: TextStyle(
                        color: Colors.purple.withOpacity(.5),
                        fontWeight: FontWeight.w600,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Divider(indent: 50, endIndent: 50),
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.all(15.0),
                      child: Text(
                        "Status: $status",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.purple.withOpacity(.5),
                          fontWeight: FontWeight.w600,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Divider(indent: 50, endIndent: 50),
                    const SizedBox(height: 40),
                    ButtonWithIcon(
                      buttonText: "Camera (Foto)",
                      height: 50,
                      width: constraints.maxWidth * .8,
                      borderRadius: 10,
                      onTap: () => takePicture(),
                      icon: Icons.photo_camera,
                    ),
                    const SizedBox(height: 20),
                    ButtonWithIcon(
                      buttonText: "Galeria (Foto)",
                      height: 50,
                      width: constraints.maxWidth * .8,
                      borderRadius: 10,
                      onTap: () => pickImage(),
                      icon: Icons.image,
                    ),
                    const SizedBox(height: 20),
                    ButtonWithIcon(
                      buttonText: "Camera (Video)",
                      height: 50,
                      width: constraints.maxWidth * .8,
                      borderRadius: 10,
                      onTap: () => takeVideo(),
                      icon: Icons.videocam,
                    ),
                    const SizedBox(height: 20),
                    ButtonWithIcon(
                      buttonText: "Galeria (Video)",
                      height: 50,
                      width: constraints.maxWidth * .8,
                      borderRadius: 10,
                      onTap: () => pickVideoFromGalery(),
                      icon: Icons.video_library,
                    ),
                    const SizedBox(height: 20),
                    ButtonWithIcon(
                      buttonText: "Pick Many",
                      height: 50,
                      width: constraints.maxWidth * .8,
                      borderRadius: 10,
                      onTap: () => pickMany(),
                      icon: Icons.image,
                    ),
                    const SizedBox(height: 20),
                    ButtonWithIcon(
                      buttonText: "Arquivos",
                      height: 50,
                      width: constraints.maxWidth * .8,
                      borderRadius: 10,
                      onTap: () => pickFile(),
                      icon: Icons.attach_file,
                    ),
                    const SizedBox(height: 20),
                    ButtonWithIcon(
                      buttonText: "Arquivos Filtrados",
                      height: 50,
                      width: constraints.maxWidth * .8,
                      borderRadius: 10,
                      onTap: () => pickFileFiltered(),
                      icon: Icons.attach_file,
                    ),
                    const SizedBox(height: 20),
                    ButtonWithIcon(
                      buttonText: "Multiplos Arquivos Filtrados",
                      height: 50,
                      width: constraints.maxWidth * .8,
                      borderRadius: 10,
                      onTap: () => pickMultipleFileFiltered().then((value) {
                        setState(() {});
                      }),
                      icon: Icons.attach_file,
                    ),
                    const SizedBox(height: 20),
                    ButtonWithIcon(
                      buttonText: "Multiplos Arquivos",
                      height: 50,
                      width: constraints.maxWidth * .8,
                      borderRadius: 10,
                      onTap: () => pickMultipleFile().then((value) {
                        setState(() {});
                      }),
                      icon: Icons.attach_file,
                    ),
                    const SizedBox(height: 20),
                    ButtonWithIcon(
                      buttonText: "Começar Audio",
                      height: 50,
                      width: constraints.maxWidth * .8,
                      borderRadius: 10,
                      onTap: () => startRecording(),
                      icon: Icons.play_circle,
                    ),
                    const SizedBox(height: 20),
                    ButtonWithIcon(
                      buttonText: "Parar Audio",
                      height: 50,
                      width: constraints.maxWidth * .8,
                      borderRadius: 10,
                      onTap: () => stopRecording(),
                      icon: Icons.stop_circle,
                    ),
                    const SizedBox(height: 50),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
