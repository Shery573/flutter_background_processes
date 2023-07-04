// ignore_for_file: file_names

import 'package:get/get.dart';

import '../Models/BackgroundServiceManager.dart';

class MyController extends GetxController {
  @override
  void onInit() async {
    BackgroundServiceManager manager = BackgroundServiceManager();
    fetchedData.value = await manager.fetchData();

    super.onInit();
  }

  var fetchedData = "".obs; // fetchedData is an observable (Rx) String

  void updateData(String newData) {
    fetchedData.value = newData;
  }
}
