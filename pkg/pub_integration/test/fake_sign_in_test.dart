// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:pub_integration/src/fake_pub_server_process.dart';
import 'package:pub_integration/src/headless_env.dart';
import 'package:test/test.dart';

void main() {
  group('fake sign in', () {
    late FakePubServerProcess fakePubServerProcess;
    late final HeadlessEnv headlessEnv;

    setUpAll(() async {
      fakePubServerProcess = await FakePubServerProcess.start();
      await fakePubServerProcess.started;
    });

    tearDownAll(() async {
      await headlessEnv.close();
      await fakePubServerProcess.kill();
    });

    test('bulk tests', () async {
      // start browser
      final origin = 'http://localhost:${fakePubServerProcess.port}';
      headlessEnv = HeadlessEnv(
        testName: 'fake_sign_in',
        origin: origin,
      );
      await headlessEnv.startBrowser();

      // init server data
      await http.post(
        Uri.parse('$origin/fake-test-profile'),
        body: json.encode(
          {
            'testProfile': {
              'defaultUser': 'admin@pub.dev',
              'packages': [
                {
                  'name': 'admin_pkg',
                },
                {
                  'name': 'user_pkg',
                  'uploaders': ['user@pub.dev'],
                },
              ],
            },
          },
        ),
      );

      String? firstSessionId;
      // sign-in page
      await headlessEnv.withPage(
        fn: (page) async {
          await page.gotoOrigin('/experimental?signin=1');
          final rs = await page.gotoOrigin('/sign-in?fake-email=user@pub.dev');
          final cookies = await page.cookies();
          final cookieNames = cookies.map((e) => e.name).toSet();
          expect(cookieNames, contains('PUB_SID_INSECURE'));
          expect(cookieNames, contains('PUB_SSID_INSECURE'));
          expect(rs.status, 200);
          final content = await page.content;
          expect(content, contains('user@pub.dev'));

          firstSessionId =
              cookies.firstWhere((c) => c.name == 'PUB_SID_INSECURE').value;
        },
      );

      // same user sign-in with redirect
      await headlessEnv.withPage(
        fn: (page) async {
          await page.gotoOrigin('/sign-in?fake-email=user@pub.dev&go=/help');
          final cookies = await page.cookies();
          final cookieNames = cookies.map((e) => e.name).toSet();
          expect(cookieNames, contains('PUB_SID_INSECURE'));
          expect(cookieNames, contains('PUB_SSID_INSECURE'));
          expect(page.url, '$origin/help');

          expect(
            cookies.firstWhere((c) => c.name == 'PUB_SID_INSECURE').value,
            firstSessionId,
          );
        },
      );

      // visiting unauthorized admin page fails
      await headlessEnv.withPage(
        fn: (page) async {
          final rs1 = await page.gotoOrigin('/packages/admin_pkg/admin');
          expect(await rs1.content,
              contains('You have insufficient permissions to view this page.'));

          final rs2 = await page.gotoOrigin('/packages/user_pkg/admin');
          final content = await rs2.content;
          expect(
              content,
              isNot(contains(
                  'You have insufficient permissions to view this page.')));
          expect(await rs2.content, contains('Automated publishing'));
        },
      );

      // sign-in with different user selected - session id changes
      await headlessEnv.withPage(
        fn: (page) async {
          await page.gotoOrigin('/sign-in?fake-email=admin@pub.dev&go=/');
          final cookies = await page.cookies();
          final cookieNames = cookies.map((e) => e.name).toSet();
          expect(cookieNames, contains('PUB_SID_INSECURE'));
          expect(cookieNames, contains('PUB_SSID_INSECURE'));
          expect(page.url, '$origin/');

          expect(
            cookies.firstWhere((c) => c.name == 'PUB_SID_INSECURE').value,
            isNot(firstSessionId),
          );
        },
      );

      // sign-out with button
      await headlessEnv.withPage(fn: (page) async {
        await page.gotoOrigin('/');
        expect(await page.content, contains('admin@pub.dev'));
        await page.hover('.nav-profile-img');
        await page.click('#-account-logout');
        await Future.delayed(Duration(seconds: 10));
        final cookies = await page.cookies();
        final cookieNames = cookies.map((e) => e.name).toSet();
        expect(cookieNames, isNot(contains('PUB_SID_INSECURE')));
        expect(cookieNames, isNot(contains('PUB_SSID_INSECURE')));
        expect(await page.content, isNot(contains('admin@pub.dev')));
      });

      // sign-in with button
      await headlessEnv.withPage(fn: (page) async {
        await page.gotoOrigin('/help');
        expect(await page.content, isNot(contains('user@pub.dev')));
        final handle = await page.$('#-account-login');
        await handle.evaluate(
            'node => node.setAttribute("data-fake-email", "user@pub.dev")');
        await page.click('#-account-login');
        await Future.delayed(Duration(seconds: 2));
        final cookies = await page.cookies();
        final cookieNames = cookies.map((e) => e.name).toSet();
        expect(cookieNames, contains('PUB_SID_INSECURE'));
        expect(cookieNames, contains('PUB_SSID_INSECURE'));
        expect(await page.content, contains('user@pub.dev'));
      });
    });
  });
}
