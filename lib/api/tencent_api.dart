import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as my_path;

import 'package:horopic/utils/common_functions.dart';
import 'package:horopic/utils/global.dart';

class TencentImageUploadUtils {
  static String _hmacSha1(String key, String data) {
    return Hmac(sha1, utf8.encode(key)).convert(utf8.encode(data)).toString();
  }

  //表单上传的signature
  static String getUploadAuthorization(
    String secretKey,
    String keyTime,
    String uploadPolicyStr,
  ) {
    String signKey = _hmacSha1(secretKey, keyTime);
    String stringtosign = sha1.convert(utf8.encode(uploadPolicyStr)).toString();
    return _hmacSha1(signKey, stringtosign);
  }

  //authorization
  static String getDeleteAuthorization(String method, String urlpath, Map header, String secretId, String secretKey) {
    int startTimestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    int endTimestamp = startTimestamp + 86400;
    String keyTime = '$startTimestamp;$endTimestamp';
    String signKey = _hmacSha1(secretKey, keyTime);
    String lowerMethod = method.toLowerCase();
    String headerList = '';
    String httpHeaders = '';
    header.forEach((key, value) {
      headerList += '${Uri.encodeComponent(key).toLowerCase()};';
      httpHeaders += '${Uri.encodeComponent(key).toLowerCase()}=${Uri.encodeComponent(value)}&';
    });
    if (headerList.isNotEmpty) {
      headerList = headerList.substring(0, headerList.length - 1);
    }
    if (httpHeaders.isNotEmpty) {
      httpHeaders = httpHeaders.substring(0, httpHeaders.length - 1);
    }
    String httpString = '$lowerMethod\n$urlpath\n\n$httpHeaders\n';
    String stringtosign = 'sha1\n$keyTime\n${sha1.convert(utf8.encode(httpString)).toString()}\n';
    String signature = Hmac(sha1, utf8.encode(signKey)).convert(utf8.encode(stringtosign)).toString();
    String authorization =
        'q-sign-algorithm=sha1&q-ak=$secretId&q-sign-time=$keyTime&q-key-time=$keyTime&q-header-list=$headerList&q-url-param-list=&q-signature=$signature';
    return authorization;
  }

  //上传接口
  static uploadApi({
    required String path,
    required String name,
    required Map configMap,
    Function(int, int)? onSendProgress,
    CancelToken? cancelToken,
  }) async {
    try {
      String secretId = configMap['secretId'] ?? '';
      String secretKey = configMap['secretKey'] ?? '';
      String bucket = configMap['bucket'] ?? '';
      String area = configMap['area'] ?? '';
      String tencentpath = configMap['path'] ?? '';
      String customUrl = configMap['customUrl'] ?? '';
      String options = configMap['options'] ?? '';

      if (customUrl != "None") {
        if (!customUrl.startsWith(RegExp(r'http(s)?://'))) {
          customUrl = 'http://$customUrl';
        }
      }

      if (tencentpath != 'None') {
        tencentpath = '${tencentpath.replaceAll(RegExp(r'^/*'), '').replaceAll(RegExp(r'/*$'), '')}/';
      }
      String host = '$bucket.cos.$area.myqcloud.com';
      //云存储的路径
      String urlpath = '';
      if (tencentpath != 'None') {
        urlpath = '/$tencentpath$name';
      } else {
        urlpath = '/$name';
      }
      int startTimestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      int endTimestamp = startTimestamp + 86400;
      String keyTime = '$startTimestamp;$endTimestamp';
      Map<String, dynamic> uploadPolicy = {
        "expiration": "2033-03-03T09:38:12.414Z",
        "conditions": [
          {"acl": "default"},
          {"bucket": bucket},
          {"key": urlpath},
          {"q-sign-algorithm": "sha1"},
          {"q-ak": secretId},
          {"q-sign-time": keyTime}
        ]
      };
      String uploadPolicyStr = jsonEncode(uploadPolicy);
      String singature = TencentImageUploadUtils.getUploadAuthorization(secretKey, keyTime, uploadPolicyStr);
      FormData formData = FormData.fromMap({
        'key': urlpath,
        'policy': base64Encode(utf8.encode(uploadPolicyStr)),
        'acl': 'default',
        'q-sign-algorithm': 'sha1',
        'q-ak': secretId,
        'q-key-time': keyTime,
        'q-sign-time': keyTime,
        'q-signature': singature,
        'file': await MultipartFile.fromFile(path, filename: my_path.basename(name)),
      });
      BaseOptions baseoptions = setBaseOptions();
      File uploadFile = File(path);
      String contentLength = await uploadFile.length().then((value) {
        return value.toString();
      });
      baseoptions.headers = {
        'Host': host,
        'Content-Type': Global.multipartString,
        'Content-Length': contentLength,
      };
      Dio dio = Dio(baseoptions);

      var response = await dio.post(
        'https://$host',
        data: formData,
        onSendProgress: onSendProgress,
        cancelToken: cancelToken,
      );
      if (response.statusCode != 204) {
        return ['failed'];
      }

      String returnUrl = '';
      String displayUrl = '';

      if (customUrl != 'None') {
        if (!customUrl.endsWith('/')) {
          returnUrl = '$customUrl$urlpath';
          displayUrl = '$customUrl$urlpath';
        } else {
          customUrl = customUrl.substring(0, customUrl.length - 1);
          returnUrl = '$customUrl$urlpath';
          displayUrl = '$customUrl$urlpath';
        }
      } else {
        returnUrl = 'https://$host$urlpath';
        displayUrl = 'https://$host$urlpath';
      }

      if (options == 'None') {
        displayUrl = displayUrl;
      } else {
        returnUrl = '$returnUrl$options';
        displayUrl = '$displayUrl$options';
      }

      String formatedURL = getFormatedUrl(returnUrl, name);
      Map pictureKeyMap = Map.from(configMap);
      String pictureKey = jsonEncode(pictureKeyMap);
      return ["success", formatedURL, returnUrl, pictureKey, displayUrl];
    } catch (e) {
      flogErr(
          e,
          {
            'path': path,
            'name': name,
          },
          "TencentImageUploadUtils",
          "uploadApi");
      return ['failed'];
    }
  }

  static deleteApi({required Map deleteMap, required Map configMap}) async {
    try {
      Map configMapFromPictureKey = jsonDecode(deleteMap['pictureKey']);
      String fileName = deleteMap['name'];
      String secretId = configMapFromPictureKey['secretId'];
      String secretKey = configMapFromPictureKey['secretKey'];
      String bucket = configMapFromPictureKey['bucket'];
      String area = configMapFromPictureKey['area'];
      String tencentpath = configMapFromPictureKey['path'];
      String deleteHost = 'https://$bucket.cos.$area.myqcloud.com';
      String urlpath = '';
      if (tencentpath != 'None') {
        if (tencentpath.startsWith('/')) {
          tencentpath = tencentpath.substring(1);
        }
        if (!tencentpath.endsWith('/')) {
          tencentpath = '$tencentpath/';
        }
        deleteHost = '$deleteHost/$tencentpath$fileName';
        urlpath = '/$tencentpath$fileName';
      } else {
        deleteHost = '$deleteHost/$fileName';
        urlpath = '/$fileName';
      }
      BaseOptions baseOptions = setBaseOptions();
      Map<String, dynamic> headers = {
        'Host': '$bucket.cos.$area.myqcloud.com',
      };
      String deleteAuthorization = TencentImageUploadUtils.getDeleteAuthorization(
        'DELETE',
        urlpath,
        headers,
        secretId,
        secretKey,
      );
      baseOptions.headers = {
        'Host': '$bucket.cos.$area.myqcloud.com',
        'Authorization': deleteAuthorization,
      };
      Dio dio = Dio(baseOptions);

      var response = await dio.delete(
        deleteHost,
      );
      if (response.statusCode != 204) {
        return ['failed'];
      }
      return ["success"];
    } catch (e) {
      flogErr(
          e,
          {
            'deleteMap': deleteMap,
            'configMap': configMap,
          },
          "TencentImageUploadUtils",
          "deleteApi");
      return ['failed'];
    }
  }
}
