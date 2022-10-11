import 'package:flutter/material.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import 'dart:convert';
import 'package:horopic/utils/common_func.dart';
import 'package:horopic/pages/loading.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:horopic/utils/sqlUtils.dart';
import 'package:horopic/utils/global.dart';

//a textfield to get hosts,username,passwd,token and strategy_id
class GithubConfig extends StatefulWidget {
  const GithubConfig({Key? key}) : super(key: key);

  @override
  _GithubConfigState createState() => _GithubConfigState();
}

class _GithubConfigState extends State<GithubConfig> {
  final _formKey = GlobalKey<FormState>();

  final _githubusernameController = TextEditingController();
  final _repoController = TextEditingController();
  final _tokenController = TextEditingController();
  final _storePathController = TextEditingController();
  final _branchController = TextEditingController();
  final _customDomainController = TextEditingController();

  @override
  void dispose() {
    _githubusernameController.dispose();
    _repoController.dispose();
    _tokenController.dispose();
    _storePathController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Github参数配置'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          children: [
            TextFormField(
              controller: _githubusernameController,
              decoration: const InputDecoration(
                label: Center(child: Text('Github用户名')),
                hintText: '设定用户名',
              ),
              textAlign: TextAlign.center,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '请输入Github用户名';
                }
                return null;
              },
            ),
            TextFormField(
              controller: _repoController,
              decoration: const InputDecoration(
                label: Center(child: Text('仓库名')),
                hintText: '设定仓库名',
              ),
              textAlign: TextAlign.center,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '请输入仓库名';
                }
                return null;
              },
            ),
            TextFormField(
              controller: _tokenController,
              obscureText: true,
              decoration: const InputDecoration(
                label: Center(child: Text('token')),
                hintText: '设定Token',
              ),
              textAlign: TextAlign.center,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '请输入token';
                }
                return null;
              },
            ),
            TextFormField(
              controller: _storePathController,
              decoration: const InputDecoration(
                contentPadding: EdgeInsets.zero,
                label: Center(child: Text('可选:存储路径')),
                hintText: '例如: test/',
              ),
              textAlign: TextAlign.center,
            ),
            TextFormField(
              controller: _branchController,
              decoration: const InputDecoration(
                contentPadding: EdgeInsets.zero,
                label: Center(child: Text('可选：分支')),
                hintText: '例如: main(默认为main)',
              ),
              textAlign: TextAlign.center,
            ),
            TextFormField(
              controller: _customDomainController,
              decoration: const InputDecoration(
                contentPadding: EdgeInsets.zero,
                label: Center(child: Text('可选：自定义域名')),
                hintText: 'eg: https://cdn.jsdelivr.net/gh/用户名/仓库名@分支名',
                hintStyle: TextStyle(fontSize: 13),
              ),
              textAlign: TextAlign.center,
            ),
            ElevatedButton(
              onPressed: () {
                if (_formKey.currentState!.validate()) {
                  showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (context) {
                        return NetLoadingDialog(
                          outsideDismiss: false,
                          loading: true,
                          loadingText: "配置中...",
                          requestCallBack: _saveGithubConfig(),
                        );
                      });
                }
              },
              child: const Text('提交表单'),
            ),
            ElevatedButton(
              onPressed: () {
                checkGithubConfig();
              },
              child: const Text('检查当前配置'),
            ),
            ElevatedButton(
              onPressed: () {
                _setdefault();
              },
              child: const Text('设为默认图床'),
            ),
          ],
        ),
      ),
    );
  }

  Future _saveGithubConfig() async {
    String token = 'Bearer ';
    String githubUserApi = 'https://api.github.com/user';
    final String githubusername = _githubusernameController.text;
    final String repo = _repoController.text;
    String storePath = '';
    if (_storePathController.text.isEmpty) {
      storePath = 'None';
    }else {
      storePath = _storePathController.text;
    }
    String branch = '';
    if (_branchController.text.isEmpty) {
      branch = 'main';
    } else {
      branch = _branchController.text;
    }
    String customDomain = '';
    if (_customDomainController.text.isEmpty) {
      customDomain = 'None';
    } else {
      customDomain = _customDomainController.text;
    }

    if (_tokenController.text.startsWith('Bearer ')) {
      token = _tokenController.text;
    } else {
      token = token + _tokenController.text;
    }

    try {
      List sqlconfig = [];
      sqlconfig.add(githubusername);
      sqlconfig.add(repo);
      sqlconfig.add(token);
      sqlconfig.add(storePath);
      sqlconfig.add(branch);
      sqlconfig.add(customDomain);
      //添加默认用户
      String defaultUser = await Global.getUser();
      sqlconfig.add(defaultUser);

      var queryGithub = await MySqlUtils.queryGithub(username: defaultUser);
      var queryuser = await MySqlUtils.queryUser(username: defaultUser);

      if (queryuser == 'Empty') {
        return showAlertDialog(
            context: context, title: '错误', content: '用户不存在,请先登录');
      }
      BaseOptions options = BaseOptions();
      options.headers = {
        "Accept": 'application/vnd.github+json',
        "Authorization": token,
      };
      //需要加一个空的formdata，不然会报错
      Map<String, dynamic> queryData = {};
      Dio dio = Dio(options);
      String sqlResult = '';
      try {
        var validateResponse =
            await dio.get(githubUserApi, queryParameters: queryData);
        if (validateResponse.statusCode == 200 &&
            validateResponse.data.toString().contains("email")) {
          //验证成功
          if (queryGithub == 'Empty') {
            sqlResult = await MySqlUtils.insertGithub(content: sqlconfig);
          } else {
            sqlResult = await MySqlUtils.updateGithub(content: sqlconfig);
          }
          if (sqlResult == "Success") {
            final githubConfig = GithubConfigModel(
                githubusername, repo, token, storePath, branch, customDomain);
            final githubConfigJson = jsonEncode(githubConfig);
            final githubConfigFile = await _localFile;
            await githubConfigFile.writeAsString(githubConfigJson);
            return showAlertDialog(
                context: context, title: '成功', content: '配置成功');
          } else {
            return showAlertDialog(
                context: context, title: '错误', content: '数据库错误');
          }
        } else {
          return showAlertDialog(
              context: context, title: '错误', content: 'token错误');
        }
      } catch (e) {
        return showAlertDialog(
            context: context, title: '错误', content: e.toString());
      }
    } catch (e) {
      return showAlertDialog(
          context: context, title: '错误', content: e.toString());
    }
  }

  void checkGithubConfig() async {
    try {
      final githubConfigFile = await _localFile;
      String configData = await githubConfigFile.readAsString();

      if (configData == "Error") {
        showAlertDialog(context: context, title: "检查失败!", content: "请先配置上传参数.");
        return;
      }

      Map configMap = jsonDecode(configData);
      BaseOptions options = BaseOptions();
      options.headers = {
        "Authorization": configMap["token"],
        "Accept": 'application/vnd.github+json',
      };
      String validateURL = "https://api.github.com/user";
      Map<String, dynamic> queryData = {};
      Dio dio = Dio(options);
      var response = await dio.get(validateURL, queryParameters: queryData);

      if (response.statusCode == 200 &&
          response.data.toString().contains("email")) {
        showAlertDialog(
            context: context,
            title: '通知',
            content: '检测通过，您的配置信息为:\n用户名: ' +
                configMap["githubusername"] +
                '\n仓库名: ' +
                configMap["repo"] +
                '\n存储路径: ' +
                configMap["storePath"] +
                '\n分支: ' +
                configMap["branch"] +
                '\n自定义域名: ' +
                configMap["customDomain"]);
      } else {
        showAlertDialog(context: context, title: '错误', content: '检查失败，请检查配置信息');
        return;
      }
    } catch (e) {
      showAlertDialog(context: context, title: "检查失败!", content: e.toString());
    }
  }

  Future<File> get _localFile async {
    final path = await _localPath;
    String defaultUser = await Global.getUser();
    return File('$path/${defaultUser}_github_config.txt');
  }

  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  Future<String> readGithubConfig() async {
    try {
      final file = await _localFile;
      String contents = await file.readAsString();
      return contents;
    } catch (e) {
      return "Error";
    }
  }

  _setdefault() async {
    try {
      String defaultUser = await Global.getUser();
      String defaultPassword = await Global.getPassword();

      var queryuser = await MySqlUtils.queryUser(username: defaultUser);
      if (queryuser == 'Empty') {
        return Fluttertoast.showToast(
            msg: "请先注册用户",
            toastLength: Toast.LENGTH_SHORT,
            timeInSecForIosWeb: 2,
            backgroundColor: Theme.of(context).brightness == Brightness.light
                ? Colors.black
                : Colors.white,
            textColor: Theme.of(context).brightness == Brightness.light
                ? Colors.white
                : Colors.black,
            fontSize: 16.0);
      } else if (queryuser['password'] != defaultPassword) {
        return Fluttertoast.showToast(
            msg: "请先登录",
            toastLength: Toast.LENGTH_SHORT,
            timeInSecForIosWeb: 2,
            backgroundColor: Theme.of(context).brightness == Brightness.light
                ? Colors.black
                : Colors.white,
            textColor: Theme.of(context).brightness == Brightness.light
                ? Colors.white
                : Colors.black,
            fontSize: 16.0);
      }

      var queryGithub = await MySqlUtils.queryGithub(username: defaultUser);
      if (queryGithub == 'Empty') {
        return Fluttertoast.showToast(
            msg: "请先配置上传参数",
            toastLength: Toast.LENGTH_SHORT,
            timeInSecForIosWeb: 2,
            backgroundColor: Theme.of(context).brightness == Brightness.light
                ? Colors.black
                : Colors.white,
            textColor: Theme.of(context).brightness == Brightness.light
                ? Colors.white
                : Colors.black,
            fontSize: 16.0);
      }
      if (queryGithub == 'Error') {
        return Fluttertoast.showToast(
            msg: "Error",
            toastLength: Toast.LENGTH_SHORT,
            timeInSecForIosWeb: 2,
            backgroundColor: Theme.of(context).brightness == Brightness.light
                ? Colors.black
                : Colors.white,
            textColor: Theme.of(context).brightness == Brightness.light
                ? Colors.white
                : Colors.black,
            fontSize: 16.0);
      }
      if (queryuser['defaultPShost'] == 'github') {
        await Global.setPShost('github');
        await Global.setShowedPBhost('github');
        return Fluttertoast.showToast(
            msg: "已经是默认配置",
            toastLength: Toast.LENGTH_SHORT,
            timeInSecForIosWeb: 2,
            backgroundColor: Theme.of(context).brightness == Brightness.light
                ? Colors.black
                : Colors.white,
            textColor: Theme.of(context).brightness == Brightness.light
                ? Colors.white
                : Colors.black,
            fontSize: 16.0);
      } else {
        List sqlconfig = [];
        sqlconfig.add(defaultUser);
        sqlconfig.add(defaultPassword);
        sqlconfig.add('github');

        var updateResult = await MySqlUtils.updateUser(content: sqlconfig);
        if (updateResult == 'Success') {
          await Global.setPShost('github');
          await Global.setShowedPBhost('github');
          Fluttertoast.showToast(
              msg: "已设置Github为默认图床",
              toastLength: Toast.LENGTH_SHORT,
              timeInSecForIosWeb: 2,
              backgroundColor: Theme.of(context).brightness == Brightness.light
                  ? Colors.black
                  : Colors.white,
              textColor: Theme.of(context).brightness == Brightness.light
                  ? Colors.white
                  : Colors.black,
              fontSize: 16.0);
        } else {
          Fluttertoast.showToast(
              msg: "写入数据库失败",
              toastLength: Toast.LENGTH_SHORT,
              timeInSecForIosWeb: 2,
              backgroundColor: Theme.of(context).brightness == Brightness.light
                  ? Colors.black
                  : Colors.white,
              textColor: Theme.of(context).brightness == Brightness.light
                  ? Colors.white
                  : Colors.black,
              fontSize: 16.0);
        }
      }
    } catch (e) {
      Fluttertoast.showToast(
          msg: "Error",
          toastLength: Toast.LENGTH_SHORT,
          timeInSecForIosWeb: 2,
          backgroundColor: Theme.of(context).brightness == Brightness.light
              ? Colors.black
              : Colors.white,
          textColor: Theme.of(context).brightness == Brightness.light
              ? Colors.white
              : Colors.black,
          fontSize: 16.0);
    }
  }
}

class GithubConfigModel {
  final String githubusername;
  final String repo;
  final String token;
  final String storePath;
  final String branch;
  final String customDomain;

  GithubConfigModel(this.githubusername, this.repo, this.token, this.storePath,
      this.branch, this.customDomain);

  Map<String, dynamic> toJson() => {
        'githubusername': githubusername,
        'repo': repo,
        'token': token,
        'storePath': storePath,
        'branch': branch,
        'customDomain': customDomain,
      };
}
