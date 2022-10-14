import 'package:dio/dio.dart';
import 'package:horopic/utils/common_func.dart';
import 'package:horopic/utils/global.dart';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';

class TencentImageUploadUtils {
  //表单上传的signature
  static String getUploadAuthorization(
      String secretKey, String keyTime, String uploadPolicyStr) {
    String signKey = Hmac(sha1, utf8.encode(secretKey))
        .convert(utf8.encode(keyTime))
        .toString();
    String stringtosign = sha1.convert(utf8.encode(uploadPolicyStr)).toString();
    String signature = Hmac(sha1, utf8.encode(signKey))
        .convert(utf8.encode(stringtosign))
        .toString();
    return signature;
  }

  //authorization
  static String getDeleteAuthorization(String method, String urlpath,
      Map header, String secretId, String secretKey) {
    int startTimestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    int endTimestamp = startTimestamp + 86400;
    String keyTime = '$startTimestamp;$endTimestamp';
    String signKey = Hmac(sha1, utf8.encode(secretKey))
        .convert(utf8.encode(keyTime))
        .toString();
    String lowerMethod = method.toLowerCase();
    String HeaderList = '';
    String HttpHeaders = '';
    header.forEach((key, value) {
      HeaderList += '${Uri.encodeComponent(key).toLowerCase()};';
      HttpHeaders +=
          '${Uri.encodeComponent(key).toLowerCase()}=${Uri.encodeComponent(value)}&';
    });
    if (HeaderList.isNotEmpty) {
      HeaderList = HeaderList.substring(0, HeaderList.length - 1);
    }
    if (HttpHeaders.isNotEmpty) {
      HttpHeaders = HttpHeaders.substring(0, HttpHeaders.length - 1);
    }
    String httpString = '$lowerMethod\n$urlpath\n\n$HttpHeaders\n';
    String stringtosign =
        'sha1\n$keyTime\n${sha1.convert(utf8.encode(httpString)).toString()}\n';
    String signature = Hmac(sha1, utf8.encode(signKey))
        .convert(utf8.encode(stringtosign))
        .toString();
    String authorization =
        'q-sign-algorithm=sha1&q-ak=$secretId&q-sign-time=$keyTime&q-key-time=$keyTime&q-header-list=$HeaderList&q-url-param-list=&q-signature=$signature';
    return authorization;
  }

  //上传接口
  static uploadApi(
      {required String path,
      required String name,
      required Map configMap}) async {
    String secretId = configMap['secretId'];
    String secretKey = configMap['secretKey'];
    String bucket = configMap['bucket'];
    String appId = configMap['appId'];
    String area = configMap['area'];
    String tencentpath = configMap['path'];
    String customUrl = configMap['customUrl'];
    String options = configMap['options'];

    if (customUrl != "None") {
      if (!customUrl.startsWith('http') && !customUrl.startsWith('https')) {
        customUrl = 'http://$customUrl';
      }
    }

    if (tencentpath != 'None') {
      if (tencentpath.startsWith('/')) {
        tencentpath = tencentpath.substring(1);
      }
      if (!tencentpath.endsWith('/')) {
        tencentpath = '$tencentpath/';
      }
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
    String singature = TencentImageUploadUtils.getUploadAuthorization(
        secretKey, keyTime, uploadPolicyStr);
    FormData formData = FormData.fromMap({
      'key': urlpath,
      'policy': base64Encode(utf8.encode(uploadPolicyStr)),
      'acl': 'default',
      'q-sign-algorithm': 'sha1',
      'q-ak': secretId,
      'q-key-time': keyTime,
      'q-sign-time': keyTime,
      'q-signature': singature,
      'file': await MultipartFile.fromFile(path, filename: name),
    });
    BaseOptions baseoptions = BaseOptions(
      //连接服务器超时时间，单位是毫秒.
      connectTimeout: 30000,
      //响应超时时间。
      receiveTimeout: 30000,
      sendTimeout: 30000,
    );
    File uploadFile = File(path);
    String contentLength = await uploadFile.length().then((value) {
      return value.toString();
    });
    baseoptions.headers = {
      'Host': host,
      'Content-Type':
          'multipart/form-data; boundary=----WebKitFormBoundary7MA4YWxkTrZu0gW',
      'Content-Length': contentLength,
    };
    Dio dio = Dio(baseoptions);

    try {
      var response = await dio.post(
        'https://$host',
        data: formData,
      );

      if (response.statusCode == 204) {
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
          displayUrl = "$displayUrl?imageMogr2/thumbnail/500x500";
        } else {
          //网站后缀以?开头
          if (!options.startsWith('?')) {
            options = '?$options';
          }
          returnUrl = '$returnUrl$options';
          displayUrl = '$displayUrl$options';
        }

        String formatedURL = '';
        if (Global.isCopyLink == true) {
          formatedURL =
              linkGenerateDict[Global.defaultLKformat]!(returnUrl, name);
        } else {
          formatedURL = returnUrl;
        }

        String pictureKey = 'None';

        return ["success", formatedURL, returnUrl, pictureKey, displayUrl];
      }
    } catch (e) {
      return [e.toString()];
    }
  }

  static deleteApi({required Map deleteMap, required Map configMap}) async {
    String fileName = deleteMap['name'];
    String secretId = configMap['secretId'];
    String secretKey = configMap['secretKey'];
    String bucket = configMap['bucket'];
    String appId = configMap['appId'];
    String area = configMap['area'];
    String tencentpath = configMap['path'];
    String customUrl = configMap['customUrl'];
    String options = configMap['options'];
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
    BaseOptions baseOptions = BaseOptions(
      //连接服务器超时时间，单位是毫秒.
      connectTimeout: 30000,
      //响应超时时间。
      receiveTimeout: 30000,
      sendTimeout: 30000,
    );
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

    try {
      var response = await dio.delete(
        deleteHost,
      );
      if (response.statusCode == 204) {
        return [
          "success",
        ];
      } else {
        return ["failed"];
      }
    } catch (e) {
      return [e.toString()];
    }
  }
}
