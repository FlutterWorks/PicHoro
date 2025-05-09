import 'dart:io';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:fluro/fluro.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as my_path;

import 'package:horopic/router/application.dart';
import 'package:horopic/utils/event_bus_utils.dart';
import 'package:horopic/utils/common_functions.dart';
import 'package:horopic/utils/global.dart';
import 'package:horopic/picture_host_manage/manage_api/aliyun_manage_api.dart';
import 'package:horopic/widgets/net_loading_dialog.dart';
import 'package:horopic/widgets/configure_widgets.dart';

class AliyunConfig extends StatefulWidget {
  const AliyunConfig({super.key});

  @override
  AliyunConfigState createState() => AliyunConfigState();
}

class AliyunConfigState extends State<AliyunConfig> {
  final _formKey = GlobalKey<FormState>();

  final _keyIdController = TextEditingController();
  final _keySecretController = TextEditingController();
  final _bucketController = TextEditingController();
  final _areaController = TextEditingController();
  final _pathController = TextEditingController();
  final _customUrlController = TextEditingController();
  final _optionsController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initConfig();
  }

  _initConfig() async {
    try {
      Map configMap = await AliyunManageAPI().getConfigMap();
      _keyIdController.text = configMap['keyId'] ?? '';
      _keySecretController.text = configMap['keySecret'] ?? '';
      _bucketController.text = configMap['bucket'] ?? '';
      _areaController.text = configMap['area'] ?? '';
      setControllerText(_pathController, configMap['path']);
      setControllerText(_customUrlController, configMap['customUrl']);
      setControllerText(_optionsController, configMap['options']);
      setState(() {});
    } catch (e) {
      flogErr(e, {}, 'AliyunConfigPage', '_initConfig');
    }
  }

  @override
  void dispose() {
    _keyIdController.dispose();
    _keySecretController.dispose();
    _bucketController.dispose();
    _areaController.dispose();
    _pathController.dispose();
    _customUrlController.dispose();
    _optionsController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ConfigureWidgets.buildConfigAppBar(title: '阿里云参数配置', context: context),
      body: Form(
        key: _formKey,
        child: ListView(
          physics: const BouncingScrollPhysics(),
          children: [
            ConfigureWidgets.buildSettingCard(
              title: '认证配置',
              children: [
                ConfigureWidgets.buildFormField(
                  controller: _keyIdController,
                  labelText: 'AccessKeyId',
                  hintText: '设定KeyId',
                  prefixIcon: Icons.key,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '请输入accessKeyId';
                    }
                    return null;
                  },
                ),
                ConfigureWidgets.buildFormField(
                  controller: _keySecretController,
                  labelText: 'AccessKeySecret',
                  hintText: '设定KeySecret',
                  prefixIcon: Icons.vpn_key,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '请输入accessKeySecret';
                    }
                    return null;
                  },
                  obscureText: true,
                ),
              ],
            ),
            ConfigureWidgets.buildSettingCard(
              title: '存储配置',
              children: [
                ConfigureWidgets.buildFormField(
                  controller: _bucketController,
                  labelText: 'Bucket',
                  hintText: '设定bucket',
                  prefixIcon: Icons.storage,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '请输入bucket';
                    }
                    return null;
                  },
                ),
                ConfigureWidgets.buildFormField(
                  controller: _areaController,
                  labelText: '存储区域',
                  hintText: '例如oss-cn-beijing',
                  prefixIcon: Icons.location_on,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '请输入存储区域';
                    }
                    return null;
                  },
                ),
              ],
            ),
            ConfigureWidgets.buildSettingCard(
              title: '路径设置',
              children: [
                ConfigureWidgets.buildFormField(
                  controller: _pathController,
                  labelText: '存储路径',
                  hintText: '例如test/（可选）',
                  prefixIcon: Icons.folder,
                ),
                ConfigureWidgets.buildFormField(
                  controller: _customUrlController,
                  labelText: '自定义域名',
                  hintText: '例如https://test.com（可选）',
                  prefixIcon: Icons.language,
                ),
                ConfigureWidgets.buildFormField(
                  controller: _optionsController,
                  labelText: '网站后缀',
                  hintText: '例如?x-oss-process=xxx（可选）',
                  prefixIcon: Icons.settings,
                ),
              ],
            ),
            ConfigureWidgets.buildSettingCard(
              title: '操作',
              children: [
                ConfigureWidgets.buildSettingItem(
                  context: context,
                  title: '保存设置',
                  icon: Icons.save,
                  onTap: () {
                    if (_formKey.currentState!.validate()) {
                      showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (context) {
                            return NetLoadingDialog(
                              outsideDismiss: false,
                              loading: true,
                              loadingText: "配置中...",
                              requestCallBack: _saveAliyunConfig(),
                            );
                          });
                    }
                  },
                ),
                ConfigureWidgets.buildDivider(),
                ConfigureWidgets.buildSettingItem(
                  context: context,
                  title: '检查当前配置',
                  icon: Icons.check_circle,
                  onTap: () {
                    showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (context) {
                          return NetLoadingDialog(
                            outsideDismiss: false,
                            loading: true,
                            loadingText: "检查中...",
                            requestCallBack: checkAliyunConfig(),
                          );
                        });
                  },
                ),
                ConfigureWidgets.buildDivider(),
                ConfigureWidgets.buildSettingItem(
                  context: context,
                  title: '设置备用配置',
                  icon: Icons.settings_backup_restore,
                  onTap: () async {
                    await Application.router
                        .navigateTo(context, '/configureStorePage?psHost=aliyun', transition: TransitionType.cupertino);
                    await _initConfig();
                    setState(() {});
                  },
                ),
                ConfigureWidgets.buildDivider(),
                ConfigureWidgets.buildSettingItem(
                  context: context,
                  title: '设为默认图床',
                  icon: Icons.favorite,
                  onTap: () {
                    _setdefault();
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future _saveAliyunConfig() async {
    try {
      String keyId = _keyIdController.text.trim();
      String keySecret = _keySecretController.text.trim();
      String bucket = _bucketController.text.trim();
      String area = _areaController.text.trim();
      String path = _pathController.text.trim();
      String customUrl = _customUrlController.text.trim();
      String options = _optionsController.text.trim();
      //格式化路径为以/结尾，不以/开头
      if (path.isEmpty || path == '/') {
        path = 'None';
      } else {
        if (!path.endsWith('/')) {
          path = '$path/';
        }
        path = path.replaceAll(RegExp(r'^/+'), '');
      }
      //格式化自定义域名，不以/结尾，以http(s)://开头
      if (customUrl.isEmpty) {
        customUrl = 'None';
      } else if (!customUrl.startsWith('http') && !customUrl.startsWith('https')) {
        customUrl = 'http://$customUrl';
      }
      customUrl = customUrl.replaceAll(RegExp(r'/+$'), '');
      //格式化网站后缀，以?开头
      if (options.isEmpty) {
        options = 'None';
      }

      final aliyunConfig = AliyunConfigModel(keyId, keySecret, bucket, area, path, customUrl, options);
      final aliyunConfigJson = jsonEncode(aliyunConfig);
      final aliyunConfigFile = await AliyunManageAPI().localFile();
      await aliyunConfigFile.writeAsString(aliyunConfigJson);
      showToast('保存成功');
    } catch (e) {
      flogErr(e, {}, 'AliyunConfigPage', 'saveAliyunConfig');
      if (context.mounted) {
        return showCupertinoAlertDialog(context: context, title: '错误', content: e.toString());
      }
    }
  }

  checkAliyunConfig() async {
    try {
      Map configMap = await AliyunManageAPI().getConfigMap();

      if (configMap.isEmpty) {
        if (context.mounted) {
          showCupertinoAlertDialog(context: context, title: "检查失败!", content: "请先配置上传参数.");
        }
        return;
      }

      //save asset image to app dir
      String assetPath = 'assets/validateImage/PicHoroValidate.jpeg';
      String appDir = await getApplicationDocumentsDirectory().then((value) {
        return value.path;
      });
      String assetFilePath = '$appDir/PicHoroValidate.jpeg';
      File assetFile = File(assetFilePath);

      if (!assetFile.existsSync()) {
        ByteData data = await rootBundle.load(assetPath);
        List<int> bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
        await assetFile.writeAsBytes(bytes);
      }
      String key = 'PicHoroValidate.jpeg';
      String host = '${configMap['bucket']}.${configMap['area']}.aliyuncs.com';
      String urlpath = '';
      if (configMap['path'] != 'None') {
        urlpath = '${configMap['path']}$key';
      } else {
        urlpath = key;
      }

      Map<String, dynamic> uploadPolicy = {
        "expiration": "2034-12-01T12:00:00.000Z",
        "conditions": [
          {"bucket": configMap['bucket']},
          ["content-length-range", 0, 104857600],
          {"key": urlpath}
        ]
      };
      String base64Policy = base64.encode(utf8.encode(json.encode(uploadPolicy)));
      String singature =
          base64.encode(Hmac(sha1, utf8.encode(configMap['keySecret'])).convert(utf8.encode(base64Policy)).bytes);
      FormData formData = FormData.fromMap({
        'key': urlpath,
        'OSSAccessKeyId': configMap['keyId'],
        'policy': base64Policy,
        'Signature': singature,
        //阿里默认的content-type是application/octet-stream，这里改成image/xxx
        'x-oss-content-type': 'image/${my_path.extension(assetFilePath).replaceFirst('.', '')}',
        'file': await MultipartFile.fromFile(assetFilePath, filename: key),
      });
      BaseOptions baseoptions = setBaseOptions();
      String contentLength = await assetFile.length().then((value) {
        return value.toString();
      });
      baseoptions.headers = {
        'Host': host,
        'Content-Length': contentLength,
      };
      Dio dio = Dio(baseoptions);
      var response = await dio.post(
        'https://$host',
        data: formData,
      );

      if (response.statusCode == 204) {
        if (context.mounted) {
          return showCupertinoAlertDialog(
              context: context,
              title: '通知',
              content:
                  '检测通过，您的配置信息为:\n\nAccessKeyId:\n${configMap['keyId']}\nAccessKeySecret:\n${configMap['keySecret']}\nBucket:\n${configMap['bucket']}\nArea:\n${configMap['area']}\nPath:\n${configMap['path']}\nCustomUrl:\n${configMap['customUrl']}\nOptions:\n${configMap['options']}');
        }
      } else {
        if (context.mounted) {
          return showCupertinoAlertDialog(context: context, title: '错误', content: '检查失败，请检查配置信息');
        }
      }
    } catch (e) {
      flogErr(e, {}, 'AliyunConfigPage', 'checkAliyunConfig');
      if (context.mounted) {
        return showCupertinoAlertDialog(context: context, title: "检查失败!", content: e.toString());
      }
    }
  }

  _setdefault() {
    Global.setPShost('aliyun');
    Global.setShowedPBhost('aliyun');
    showToast('已设置阿里云为默认图床');
    eventBus.fire(HomePhotoRefreshEvent(homePhotoKeepAlive: false));
  }
}

class AliyunConfigModel {
  final String keyId;
  final String keySecret;
  final String bucket;
  final String area;
  final String path;
  final String customUrl;
  final String options;

  AliyunConfigModel(this.keyId, this.keySecret, this.bucket, this.area, this.path, this.customUrl, this.options);

  Map<String, dynamic> toJson() => {
        'keyId': keyId,
        'keySecret': keySecret,
        'bucket': bucket,
        'area': area,
        'path': path,
        'customUrl': customUrl,
        'options': options,
      };

  static List keysList = [
    'remarkName',
    'keyId',
    'keySecret',
    'bucket',
    'area',
    'path',
    'customUrl',
    'options',
  ];
}
