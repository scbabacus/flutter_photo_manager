import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

class PhotoList extends StatefulWidget {
  final List<AssetEntity> photos;

  PhotoList({this.photos});

  @override
  _PhotoListState createState() => _PhotoListState();
}

class _PhotoListState extends State<PhotoList> {
  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1.0,
      ),
      itemBuilder: _buildItem,
      itemCount: widget.photos.length,
    );
  }

  Widget _buildItem(BuildContext context, int index) {
    var entity = widget.photos[index];
    print("请求的index = $index , image id = ${entity.id} type = ${entity.type}");
    return FutureBuilder<Uint8List>(
      future: entity.thumbData,
      builder: (BuildContext context, AsyncSnapshot<Uint8List> snapshot) {
        if (snapshot.connectionState == ConnectionState.done && snapshot.data != null) {
          return InkWell(
            onTap: () => showInfo(entity),
            child: Stack(
              children: <Widget>[
                Image.memory(
                  snapshot.data,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                ),
                IgnorePointer(
                  child: Container(
                    alignment: Alignment.center,
                    child: Text(
                      '${entity.type}',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          );
        }
        return Center(
          child: Text('加载中'),
        );
      },
    );
  }

  showInfo(AssetEntity entity) async {
    if (entity.type == AssetType.video) {
      var file = await entity.file;
      var length = file.lengthSync();
      print("${entity.id} length = $length");
    }
  }
}
