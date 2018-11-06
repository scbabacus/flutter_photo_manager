import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';

enum AssetType {
  other,
  image,
  video,
}

class PhotoManager {
  static const MethodChannel _channel = const MethodChannel('image_scanner');

  /// in android WRITE_EXTERNAL_STORAGE  READ_EXTERNAL_STORAGE
  ///
  /// in ios request the photo permission
  static Future<bool> requestPermission() async {
    var result = await _channel.invokeMethod("requestPermission");
    return result == 1;
  }

  /// get gallery list
  ///
  /// 获取相册"文件夹" 列表
  ///
  /// [hasAll] contains all path
  /// [hasAll] 包含所有文件
  ///
  /// [hasVideo] contains video
  /// [hasVideo] 包含视频
  ///
  static Future<List<AssetPathEntity>> getAssetPathList({
    bool hasAll = true,
    bool hasVideo = true,
  }) async {
    /// 获取id 列表
    List list = await _channel.invokeMethod('getGalleryIdList');
    if (list == null) {
      return [];
    }

    List<AssetPathEntity> pathList = await _getPathList(
      list.map((v) => v.toString()).toList(),
      hasVideo: hasVideo,
    );

    if (hasAll == true) {
      AssetPathEntity.all.hasVideo = hasVideo;
      pathList.insert(0, AssetPathEntity.all);
    }

    return pathList;
  }

  static void openSetting() {
    _channel.invokeMethod("openSetting");
  }

  static Future<List<AssetPathEntity>> _getPathList(List<String> idList, {bool hasVideo}) async {
    hasVideo ??= true;

    /// 获取文件夹列表,这里主要是获取相册名称
    var list = await _channel.invokeMethod("getGalleryNameList", idList);

    List<AssetPathEntity> result = [];
    for (var i = 0; i < idList.length; i++) {
      var entity = AssetPathEntity(
        id: idList[i],
        name: list[i].toString(),
        hasVideo: hasVideo,
      );
      result.add(entity);
    }

    return result;
  }

  static AssetType _convertTypeFromString(String type) {
    // print("type = $type");
    try {
      var intType = int.tryParse(type) ?? 0;
      return AssetType.values[intType];
    } on Exception {
      return AssetType.other;
    }
  }

  /// get image entity with path
  ///
  /// 获取指定相册下的所有内容
  static Future<List<AssetEntity>> _getImageList(AssetPathEntity path) async {
    List<dynamic> list;
    if (path.id == AssetPathEntity.all.id) {
      list = await _channel.invokeMethod("getAllImageList");
    } else {
      list = await _channel.invokeMethod("getImageListWithPathId", path.id);
    }
    var entityList = list.map((v) => AssetEntity(id: v.toString())).toList();
    await _fetchType(entityList);
    return _filterType(entityList, path.hasVideo == true);
  }

  static List<AssetEntity> _filterType(List<AssetEntity> list, bool hasVideo) {
    hasVideo ??= true;

    return list.where((it) {
      if (it.type == AssetType.image) {
        return true;
      } else {
        return it.type == AssetType.video && hasVideo;
      }
    }).toList();
  }

  static Future _fetchType(List<AssetEntity> entityList) async {
    var ids = entityList.map((v) => v.id).toList();
    List typeList = await _channel.invokeMethod("getAssetTypeWithIds", ids);

    for (var i = 0; i < typeList.length; i++) {
      var entity = entityList[i];
      entity.type = _convertTypeFromString(typeList[i]);
    }
  }

  static Future<File> _getFullFileWithId(String id) async {
    if (Platform.isAndroid) {
      return File(id);
    } else if (Platform.isIOS) {
      var path = await _channel.invokeMethod("getFullFileWithId", id);
      if (path == null) {
        return null;
      }
      return File(path);
    }
    return null;
  }

  static Future<List<int>> _getDataWithId(String id) async {
    if (Platform.isAndroid) {
      return File(id).readAsBytes();
    } else if (Platform.isIOS) {
      List<dynamic> bytes = await _channel.invokeMethod("getBytesWithId", id);
      if (bytes == null) {
        return null;
      }
      List<int> l = bytes.map((v) {
        if (v is int) {
          return v;
        }
        return 0;
      }).toList();

      return l;
    }
    return null;
  }

  static Future<Uint8List> _getThumbDataWithId(
    String id, {
    int width = 64,
    int height = 64,
  }) async {
    Completer<Uint8List> completer = Completer();
    Future.delayed(Duration.zero, () async {
      var result = await _channel.invokeMethod("getThumbBytesWithId", [id, width.toString(), height.toString()]);
      if (result is Uint8List) {
        completer.complete(null);
      } else if (result is List<dynamic>) {
        List<int> l = result.map((v) {
          if (v is int) {
            return v;
          }
          return 0;
        }).toList();
        completer.complete(Uint8List.fromList(l));
      } else {
        print("加载错误");
        completer.completeError("图片加载发生错误");
      }
    });

    return completer.future;
  }

  static Future<bool> _isCloudWithAsset(AssetEntity assetEntity) async {
    if (Platform.isAndroid) {
      return false;
    }
    if (Platform.isIOS) {
      var isICloud = await _channel.invokeMethod("isCloudWithImageId", assetEntity.id);
      return isICloud == "1";
    }
    return null;
  }

  static Future<double> _getLatitudeWithId(String id) async {
    // TODO: to be implemented
    if (Platform.isAndroid) {
      return Future.value(0.0);
    }
    if (Platform.isIOS) {
      return await _channel.invokeMethod("getLatitudeWithId", id);
    }

    return Future.value(0.0);
  }

  static Future<double> _getLongitudeWithId(String id) async {
    // TODO: to be implemented
    if (Platform.isAndroid) {
      return Future.value(0.0);
    }
    if (Platform.isIOS) {
      return await _channel.invokeMethod("getLongitudeWithId", id);
    }

    return Future.value(0.0);
  }

  static Future<double> _getCreationDateWithId(String id) async {
    // TODO: to be implemented
    if (Platform.isAndroid) {
      return Future.value(0.0);
    }
    if (Platform.isIOS) {
      return await _channel.invokeMethod("getCreationDateWithId", id);
    }

    return Future.value(0.0);
  }
}

/// image entity
class AssetEntity {
  Future<double> get latitude => PhotoManager._getLatitudeWithId(id);
  Future<double> get longitude => PhotoManager._getLongitudeWithId(id);
  Future<double> get creationDate => PhotoManager._getCreationDateWithId(id); // as unix timestamp

  /// in android is full path
  ///
  /// in ios is asset id
  String id;

  /// the asset type
  ///
  /// see [AssetType]
  AssetType type;

  // /// isCloud
  // Future get isCloud async => PhotoManager._isCloudWithAsset(this);

  /// thumb path
  ///
  /// you can use File(path) to use
  // Future<File> get thumb async => PhotoManager._getThumbWithId(id);

  /// if you need upload file ,then you can use the file
  Future<File> get file async => PhotoManager._getFullFileWithId(id);

  /// the image's bytes ,
  Future<List<int>> get fullData => PhotoManager._getDataWithId(id);

  /// thumb data , for display
  Future<Uint8List> get thumbData => PhotoManager._getThumbDataWithId(id);

  Future<Uint8List> thumbDataWithSize(int width, int height) {
    return PhotoManager._getThumbDataWithId(id, width: width, height: height);
  }

  AssetEntity({this.id});

  @override
  int get hashCode {
    return id.hashCode;
  }

  @override
  bool operator ==(other) {
    if (other is! AssetEntity) {
      return false;
    }
    return this.id == other.id;
  }
}

/// Gallery Id
class AssetPathEntity {
  /// id
  ///
  /// in ios is localIdentifier
  ///
  /// in android is content provider database _id column
  String id;

  /// name
  ///
  /// in android is path name
  ///
  /// in ios is photos gallery name
  String name;

  /// hasVideo
  bool hasVideo;

  AssetPathEntity({this.id, this.name, this.hasVideo});

  /// the image entity list
  Future<List<AssetEntity>> get assetList => PhotoManager._getImageList(this);

  static var _all = AssetPathEntity()
    ..id = "dfnsfkdfj2454AJJnfdkl"
    ..name = "全部"
    ..hasVideo = true;

  static AssetPathEntity get all => _all;

  @override
  bool operator ==(other) {
    if (other is! AssetPathEntity) {
      return false;
    }
    return this.id == other.id;
  }

  @override
  int get hashCode {
    return this.id.hashCode;
  }
}
