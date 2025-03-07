// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'script/public_pages.dart';
import 'script/publishing.dart';

/// Runs the integration tests on the [pubHostedUrl].
Future verifyPub({
  required String pubHostedUrl,
  required String credentialsFileContent,
  required String mainAccessToken,
  required String invitedEmail,
  required InviteCompleterFn inviteCompleterFn,
  bool expectLiveSite = true,
}) async {
  final pubToolScript = PublishingScript(
    pubHostedUrl,
    credentialsFileContent,
    mainAccessToken,
    invitedEmail,
    inviteCompleterFn,
    expectLiveSite,
  );
  await pubToolScript.verify();

  final publicPagesScript = PublicPagesScript(
    pubHostedUrl,
    expectLiveSite: expectLiveSite,
  );
  await publicPagesScript.verify();
}
