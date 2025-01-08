import 'package:flutter/material.dart';

class CameraSourceSelectionView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Select Camera Source")),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ElevatedButton(
            onPressed: () {
              Navigator.pushNamed(context, '/cameraGrid', arguments: 'local');
            },
            child: Text("Use Local Camera"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pushNamed(context, '/cameraGrid', arguments: 'server');
            },
            child: Text("Use Remote Server"),
          ),
        ],
      ),
    );
  }
}
