import 'package:dio/dio.dart';
import 'package:horopic/utils/common_func.dart';
import 'package:horopic/utils/global.dart';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as mypath;

class AliyunImageUploadUtils {
  //上传接口
  static uploadApi(
      {required String path,
      required String name,
      required Map configMap}) async {
    String keyId = configMap['keyId'];
    String keySecret = configMap['keySecret'];
    String bucket = configMap['bucket'];
    String area = configMap['area'];
    String aliyunpath = configMap['path'];
    String customUrl = configMap['customUrl'];
    String options = configMap['options'];
    //格式化
    if (customUrl != "None") {
      if (!customUrl.startsWith('http') && !customUrl.startsWith('https')) {
        customUrl = 'http://$customUrl';
      }
    }
    //格式haul
    if (aliyunpath != 'None') {
      if (aliyunpath.startsWith('/')) {
        aliyunpath = aliyunpath.substring(1);
      }
      if (!aliyunpath.endsWith('/')) {
        aliyunpath = '$aliyunpath/';
      }
    }
    String host = '$bucket.$area.aliyuncs.com';
    //云存储的路径
    String urlpath = '';
    //阿里云不能以/开头
    if (aliyunpath != 'None') {
      urlpath = '$aliyunpath$name';
    } else {
      urlpath = name;
    }

    Map<String, dynamic> uploadPolicy = {
      "expiration": "2034-12-01T12:00:00.000Z",
      "conditions": [
        {"bucket": bucket},
        ["content-length-range", 0, 104857600],
        {"key": urlpath}
      ]
    };
    String base64Policy = base64.encode(utf8.encode(json.encode(uploadPolicy)));
    String singature = base64.encode(Hmac(sha1, utf8.encode(keySecret))
        .convert(utf8.encode(base64Policy))
        .bytes);
    FormData formData = FormData.fromMap({
      'key': urlpath,
      'OSSAccessKeyId': keyId,
      'policy': base64Policy,
      'Signature': singature,
      'x-oss-content-type':
          'image/${mypath.extension(path).replaceFirst('.', '')}',
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
            returnUrl = '$customUrl/$urlpath';
            displayUrl = '$customUrl/$urlpath';
          } else {
            customUrl = customUrl.substring(0, customUrl.length - 1);
            returnUrl = '$customUrl/$urlpath';
            displayUrl = '$customUrl/$urlpath';
          }
        } else {
          returnUrl = 'https://$host/$urlpath';
          displayUrl = 'https://$host/$urlpath';
        }

        if (options == 'None') {
          displayUrl =
              "$displayUrl?x-oss-process=image/resize,m_lfit,h_500,w_500";
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
    String keyId = configMap['keyId'];
    String keySecret = configMap['keySecret'];
    String bucket = configMap['bucket'];
    String area = configMap['area'];
    String aliyunpath = configMap['path'];
    String deleteHost = 'https://$bucket.$area.aliyuncs.com';
    String urlpath = '';
    if (aliyunpath != 'None') {
      if (aliyunpath.startsWith('/')) {
        aliyunpath = aliyunpath.substring(1);
      }
      if (!aliyunpath.endsWith('/')) {
        aliyunpath = '$aliyunpath/';
      }
      deleteHost = '$deleteHost/$aliyunpath$fileName';
      urlpath = '$aliyunpath$fileName';
    } else {
      deleteHost = '$deleteHost/$fileName';
      urlpath = fileName;
    }
    BaseOptions baseOptions = BaseOptions(
      //连接服务器超时时间，单位是毫秒.
      connectTimeout: 30000,
      //响应超时时间。
      receiveTimeout: 30000,
      sendTimeout: 30000,
    );
    String authorization = 'OSS $keyId:';
    var date = HttpDate.format(DateTime.now());
    String verb = 'DELETE';
    String contentMD5 = '';
    String contentType = 'application/json';
    String canonicalizedOSSHeaders = '';
    String canonicalizedResource = '/$bucket/$urlpath';
    String stringToSign =
        '$verb\n$contentMD5\n$contentType\n$date\n$canonicalizedOSSHeaders$canonicalizedResource';
    String signature = base64.encode(Hmac(sha1, utf8.encode(keySecret))
        .convert(utf8.encode(stringToSign))
        .bytes);

    baseOptions.headers = {
      'Host': '$bucket.$area.aliyuncs.com',
      'Authorization': '$authorization$signature',
      'Date': HttpDate.format(DateTime.now()),
      'Content-type': 'application/json',
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
