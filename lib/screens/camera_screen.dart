import 'dart:developer';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_camera_demo/screens/preview_screen.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../main.dart';

class CameraScreen extends StatefulWidget {
  @override
  _CameraScreenState createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver {
  CameraController? controller;

  File? _imageFile;

  // Initial values
  bool _isCameraInitialized = false;
  bool _isCameraPermissionGranted = false;
  bool _isRearCameraSelected = true;
  bool _isRecordingInProgress = false;
  double _minAvailableExposureOffset = 0.0;
  double _maxAvailableExposureOffset = 0.0;
  double _minAvailableZoom = 1.0;
  double _maxAvailableZoom = 1.0;

  // Current values
  double _currentZoomLevel = 1.0;
  double _currentExposureOffset = 0.0;
  FlashMode? _currentFlashMode;

  List<File> allFileList = [];

  final resolutionPresets = ResolutionPreset.values;

  ResolutionPreset currentResolutionPreset = ResolutionPreset.high;

  getPermissionStatus() async {
    await Permission.camera.request();
    var status = await Permission.camera.status;

    if (status.isGranted) {
      log('Camera Permission: GRANTED');
      setState(() {
        _isCameraPermissionGranted = true;
      });
      // Set and initialize the new camera
      onNewCameraSelected(cameras[0]);
      refreshAlreadyCapturedImages();
    } else {
      log('Camera Permission: DENIED');
    }
  }

  refreshAlreadyCapturedImages() async {
    final directory = await getApplicationDocumentsDirectory();
    List<FileSystemEntity> fileList = await directory.list().toList();
    allFileList.clear();
    List<Map<int, dynamic>> fileNames = [];

    fileList.forEach((file) {
      if (file.path.contains('.jpg') || file.path.contains('.mp4')) {
        allFileList.add(File(file.path));

        String name = file.path.split('/').last.split('.').first;
        fileNames.add({0: int.parse(name), 1: file.path.split('/').last});
      }
    });

    if (fileNames.isNotEmpty) {
      final recentFile =
          fileNames.reduce((curr, next) => curr[0] > next[0] ? curr : next);
      String recentFileName = recentFile[1];

      _imageFile = File('${directory.path}/$recentFileName');

      setState(() {});
    }
  }

  Future<XFile?> takePicture() async {
    print("called");
    final CameraController? cameraController = controller;

    if (cameraController!.value.isTakingPicture) {
      // A capture is already pending, do nothing.
      return null;
    }
    try {
      XFile file = await cameraController.takePicture();
      print(file.path);
      return file;
    } on CameraException catch (e) {
      print('Error occured while taking picture: $e');
      return null;
    }
  }

  void resetCameraValues() async {
    _currentZoomLevel = 1.0;
    _currentExposureOffset = 0.0;
  }

  void onNewCameraSelected(CameraDescription cameraDescription) async {
    final previousCameraController = controller;

    final CameraController cameraController = CameraController(
      cameraDescription,
      currentResolutionPreset,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    await previousCameraController?.dispose();

    resetCameraValues();

    if (mounted) {
      setState(() {
        controller = cameraController;
      });
    }

    // Update UI if controller updated
    cameraController.addListener(() {
      if (mounted) setState(() {});
    });

    try {
      await cameraController.initialize();
      await Future.wait([
        cameraController
            .getMinExposureOffset()
            .then((value) => _minAvailableExposureOffset = value),
        cameraController
            .getMaxExposureOffset()
            .then((value) => _maxAvailableExposureOffset = value),
        cameraController
            .getMaxZoomLevel()
            .then((value) => _maxAvailableZoom = value),
        cameraController
            .getMinZoomLevel()
            .then((value) => _minAvailableZoom = value),
      ]);

      _currentFlashMode = FlashMode.off;
    } on CameraException catch (e) {
      print('Error initializing camera: $e');
    }

    if (mounted) {
      setState(() {
        _isCameraInitialized = controller!.value.isInitialized;
      });
    }
  }

  void onViewFinderTap(TapDownDetails details, BoxConstraints constraints) {
    if (controller == null) {
      return;
    }

    final offset = Offset(
      details.localPosition.dx / constraints.maxWidth,
      details.localPosition.dy / constraints.maxHeight,
    );
    controller!.setExposurePoint(offset);
    controller!.setFocusPoint(offset);
  }

  @override
  void initState() {
    // Hide the status bar in Android
    // SystemChrome.setEnabledSystemUIOverlays([]);
    getPermissionStatus();
    super.initState();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = controller;

    // App state changed before we got the chance to initialize.
    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      cameraController.dispose();
    } else if (state == AppLifecycleState.resumed) {
      onNewCameraSelected(cameraController.description);
    }
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var size = MediaQuery.of(context).size.width;
    return SafeArea(
      child: Scaffold(
        backgroundColor: Color(0xff626262),
        body: _isCameraPermissionGranted
            ? _isCameraInitialized
                ? Column(
                    children: [
                      Stack(
                        children: [
                          // Center(
                          //   child: Container(
                          //     padding: EdgeInsets.all(10),
                          //     width: size,
                          //     height: size,
                          //     child: ClipRect(
                          //       child: OverflowBox(
                          //         alignment: Alignment.center,
                          //         child: FittedBox(
                          //           fit: BoxFit.fitWidth,
                          //           child: Container(
                          //             width: size,
                          //             height: size /
                          //                 controller!.value.aspectRatio,
                          //             child: CameraPreview(
                          //               controller!,
                          //             ), // this is my CameraPreview
                          //           ),
                          //         ),
                          //       ),
                          //     ),
                          //   ),
                          // ),

                          AspectRatio(
                            aspectRatio: 1 / controller!.value.aspectRatio,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                              ),
                              child: CameraPreview(
                                controller!,
                                // child: LayoutBuilder(builder:
                                //     (BuildContext context,
                                //         BoxConstraints constraints) {
                                //   return GestureDetector(
                                //     behavior: HitTestBehavior.opaque,
                                //     onTapDown: (details) =>
                                //         onViewFinderTap(details, constraints),
                                //   );
                                // }),
                              ),
                            ),
                          ),

                          // Positioned.fill(
                          //   child: DocumentOverlay(), // Custom Overlay
                          // ),
                          Positioned.fill(
                            top: 510,
                            child: Container(
                              color: Color(0xff626262),
                              height: 250,
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16.0,
                                  8.0,
                                  16.0,
                                  8.0,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    // Align(
                                    //   alignment: Alignment.topRight,
                                    //   child: Container(
                                    //     decoration: BoxDecoration(
                                    //       color: Colors.black87,
                                    //       borderRadius:
                                    //           BorderRadius.circular(10.0),
                                    //     ),
                                    //     child: Padding(
                                    //       padding: const EdgeInsets.only(
                                    //         left: 8.0,
                                    //         right: 8.0,
                                    //       ),
                                    //       child: DropdownButton<ResolutionPreset>(
                                    //         dropdownColor: Colors.black87,
                                    //         underline: Container(),
                                    //         value: currentResolutionPreset,
                                    //         items: [
                                    //           for (ResolutionPreset preset
                                    //               in resolutionPresets)
                                    //             DropdownMenuItem(
                                    //               child: Text(
                                    //                 preset
                                    //                     .toString()
                                    //                     .split('.')[1]
                                    //                     .toUpperCase(),
                                    //                 style: TextStyle(
                                    //                     color: Colors.white),
                                    //               ),
                                    //               value: preset,
                                    //             )
                                    //         ],
                                    //         onChanged: (value) {
                                    //           setState(() {
                                    //             currentResolutionPreset = value!;
                                    //             _isCameraInitialized = false;
                                    //           });
                                    //           onNewCameraSelected(
                                    //               controller!.description);
                                    //         },
                                    //         hint: Text("Select item"),
                                    //       ),
                                    //     ),
                                    //   ),
                                    // ),
                                    // Spacer(),
                                    // Padding(
                                    //   padding: const EdgeInsets.only(
                                    //       right: 8.0, top: 16.0),
                                    //   child: Container(
                                    //     decoration: BoxDecoration(
                                    //       color: Colors.white,
                                    //       borderRadius:
                                    //           BorderRadius.circular(10.0),
                                    //     ),
                                    //     child: Padding(
                                    //       padding: const EdgeInsets.all(8.0),
                                    //       child: Text(
                                    //         _currentExposureOffset
                                    //                 .toStringAsFixed(1) +
                                    //             'x',
                                    //         style: TextStyle(color: Colors.black),
                                    //       ),
                                    //     ),
                                    //   ),
                                    // ),
                                    // Expanded(
                                    //   child: RotatedBox(
                                    //     quarterTurns: 3,
                                    //     child: Container(
                                    //       height: 30,
                                    //       child: Slider(
                                    //         value: _currentExposureOffset,
                                    //         min: _minAvailableExposureOffset,
                                    //         max: _maxAvailableExposureOffset,
                                    //         activeColor: Colors.white,
                                    //         inactiveColor: Colors.white30,
                                    //         onChanged: (value) async {
                                    //           setState(() {
                                    //             _currentExposureOffset = value;
                                    //           });
                                    //           await controller!
                                    //               .setExposureOffset(value);
                                    //         },
                                    //       ),
                                    //     ),
                                    //   ),
                                    // ),
                                    // Row(
                                    //   children: [
                                    // Expanded(
                                    //   child: Slider(
                                    //     value: _currentZoomLevel,
                                    //     min: _minAvailableZoom,
                                    //     max: _maxAvailableZoom,
                                    //     activeColor: Colors.white,
                                    //     inactiveColor: Colors.white30,
                                    //     onChanged: (value) async {
                                    //       setState(() {
                                    //         _currentZoomLevel = value;
                                    //       });
                                    //       await controller!
                                    //           .setZoomLevel(value);
                                    //     },
                                    //   ),
                                    // ),
                                    // Padding(
                                    //   padding:
                                    //       const EdgeInsets.only(right: 8.0),
                                    //   child: Container(
                                    //     decoration: BoxDecoration(
                                    //       color: Colors.black87,
                                    //       borderRadius:
                                    //           BorderRadius.circular(10.0),
                                    //     ),
                                    //     child: Padding(
                                    //       padding: const EdgeInsets.all(8.0),
                                    //       child: Text(
                                    //         _currentZoomLevel
                                    //                 .toStringAsFixed(1) +
                                    //             'x',
                                    //         style: TextStyle(
                                    //             color: Colors.white),
                                    //       ),
                                    //     ),
                                    //   ),
                                    // ),
                                    //   ],
                                    // ),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        InkWell(
                                          onTap: () {
                                            setState(() {
                                              _isCameraInitialized = false;
                                            });
                                            onNewCameraSelected(cameras[
                                                _isRearCameraSelected ? 1 : 0]);
                                            setState(() {
                                              _isRearCameraSelected =
                                                  !_isRearCameraSelected;
                                            });
                                          },
                                          child: Stack(
                                            alignment: Alignment.center,
                                            children: [
                                              Icon(
                                                Icons.circle,
                                                color: Colors.black38,
                                                size: 60,
                                              ),
                                              _isRecordingInProgress
                                                  ? controller!.value
                                                          .isRecordingPaused
                                                      ? Icon(
                                                          Icons.play_arrow,
                                                          color: Colors.white,
                                                          size: 30,
                                                        )
                                                      : Icon(
                                                          Icons.pause,
                                                          color: Colors.white,
                                                          size: 30,
                                                        )
                                                  : Icon(
                                                      _isRearCameraSelected
                                                          ? Icons.camera_front
                                                          : Icons.camera_rear,
                                                      color: Colors.white,
                                                      size: 30,
                                                    ),
                                            ],
                                          ),
                                        ),
                                        InkWell(
                                          onTap: () async {
                                            XFile? rawImage =
                                                await takePicture();
                                            File imageFile =
                                                File(rawImage!.path);

                                            int currentUnix = DateTime.now()
                                                .millisecondsSinceEpoch;

                                            final directory =
                                                await getApplicationDocumentsDirectory();

                                            String fileFormat =
                                                imageFile.path.split('.').last;

                                            print(fileFormat);

                                            await imageFile.copy(
                                              '${directory.path}/$currentUnix.$fileFormat',
                                            );

                                            refreshAlreadyCapturedImages();
                                          },
                                          child: Stack(
                                            alignment: Alignment.center,
                                            children: [
                                              Icon(
                                                Icons.circle,
                                                color: Color(0xffbbbbbb),
                                                size: 120,
                                              ),
                                              Icon(
                                                Icons.circle,
                                                color: Color(0xff126ff6),
                                                size: 100,
                                              ),
                                            ],
                                          ),
                                        ),
                                        InkWell(
                                          onTap: _imageFile != null
                                              ? () {
                                                  Navigator.of(context).push(
                                                    MaterialPageRoute(
                                                      builder: (context) =>
                                                          PreviewScreen(
                                                        imageFile: _imageFile!,
                                                        fileList: allFileList,
                                                      ),
                                                    ),
                                                  );
                                                }
                                              : null,
                                          child: Container(
                                            width: 60,
                                            height: 60,
                                            decoration: BoxDecoration(
                                              color: Colors.black,
                                              borderRadius:
                                                  BorderRadius.circular(10.0),
                                              border: Border.all(
                                                color: Colors.white,
                                                width: 2,
                                              ),
                                              image: _imageFile != null
                                                  ? DecorationImage(
                                                      image: FileImage(
                                                          _imageFile!),
                                                      fit: BoxFit.cover,
                                                    )
                                                  : null,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Positioned.fill(
                            bottom: 510,
                            child: Container(
                              color: Color(0xff626262),
                              height: 250,
                            ),
                          ),
                        ],
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          physics: BouncingScrollPhysics(),
                          child: Column(
                            children: [
                              // Padding(
                              //   padding: const EdgeInsets.only(top: 8.0),
                              //   child: Row(
                              //     children: [
                              //       Expanded(
                              //         child: Padding(
                              //           padding: const EdgeInsets.only(
                              //             left: 8.0,
                              //             right: 4.0,
                              //           ),
                              //           child: TextButton(
                              //             onPressed: _isRecordingInProgress
                              //                 ? null
                              //                 : () {
                              //                     if (_isVideoCameraSelected) {
                              //                       setState(() {
                              //                         _isVideoCameraSelected =
                              //                             false;
                              //                       });
                              //                     }
                              //                   },
                              //             child: Text('IMAGE'),
                              //           ),
                              //         ),
                              //       ),
                              //       Expanded(
                              //         child: Padding(
                              //           padding: const EdgeInsets.only(
                              //               left: 4.0, right: 8.0),
                              //           child: TextButton(
                              //             onPressed: () {
                              //               if (!_isVideoCameraSelected) {
                              //                 setState(() {
                              //                   _isVideoCameraSelected = true;
                              //                 });
                              //               }
                              //             },
                              //             child: Text('VIDEO'),
                              //           ),
                              //         ),
                              //       ),
                              //     ],
                              //   ),
                              // ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                    16.0, 8.0, 16.0, 8.0),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    InkWell(
                                      onTap: () async {
                                        setState(() {
                                          _currentFlashMode = FlashMode.off;
                                        });
                                        await controller!.setFlashMode(
                                          FlashMode.off,
                                        );
                                      },
                                      child: Icon(
                                        Icons.flash_off,
                                        color:
                                            _currentFlashMode == FlashMode.off
                                                ? Colors.amber
                                                : Colors.white,
                                      ),
                                    ),
                                    InkWell(
                                      onTap: () async {
                                        setState(() {
                                          _currentFlashMode = FlashMode.auto;
                                        });
                                        await controller!.setFlashMode(
                                          FlashMode.auto,
                                        );
                                      },
                                      child: Icon(
                                        Icons.flash_auto,
                                        color:
                                            _currentFlashMode == FlashMode.auto
                                                ? Colors.amber
                                                : Colors.white,
                                      ),
                                    ),
                                    InkWell(
                                      onTap: () async {
                                        setState(() {
                                          _currentFlashMode = FlashMode.always;
                                        });
                                        await controller!.setFlashMode(
                                          FlashMode.always,
                                        );
                                      },
                                      child: Icon(
                                        Icons.flash_on,
                                        color: _currentFlashMode ==
                                                FlashMode.always
                                            ? Colors.amber
                                            : Colors.white,
                                      ),
                                    ),
                                    InkWell(
                                      onTap: () async {
                                        setState(() {
                                          _currentFlashMode = FlashMode.torch;
                                        });
                                        await controller!.setFlashMode(
                                          FlashMode.torch,
                                        );
                                      },
                                      child: Icon(
                                        Icons.highlight,
                                        color:
                                            _currentFlashMode == FlashMode.torch
                                                ? Colors.amber
                                                : Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            ],
                          ),
                        ),
                      ),
                    ],
                  )
                : Center(
                    child: Text(
                      'LOADING',
                      style: TextStyle(color: Colors.white),
                    ),
                  )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(),
                  Text(
                    'Permission denied',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                    ),
                  ),
                  SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      getPermissionStatus();
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        'Give permission',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class DocumentOverlay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Dark background with some transparency
        Container(
          color: Colors.black.withOpacity(0.6),
        ),
        // Transparent area in the center
        Align(
          alignment: Alignment.center,
          child: Container(
            width: MediaQuery.of(context).size.width * 0.8,
            height: MediaQuery.of(context).size.width * 0.5,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white, width: 2),
              color: Colors.transparent,
            ),
          ),
        ),
      ],
    );
  }
}
