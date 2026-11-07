// Licensed under the Apache License, Version 2.0
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:otel_vtex/otel_vtex.dart';

/// Traces VTEX calls with OpenTelemetry.
///
/// `otel_vtex` depends on the OpenTelemetry API only, so the application
/// initializes an SDK once at startup. Wrap each VTEX call in
/// [tracedVtex]; the `invoke` callback makes the real call and reports what
/// came back, which is recorded on the span.
Future<void> main() async {
  await OTel.initialize(serviceName: 'vtex-example');

  // Wraps a VTEX API call in a CLIENT span.
  final vtexId = await tracedVtex<String>(
    operation: 'master_data.entity.create',
    module: 'example',
    account: 'example',
    invoke: () async {
      // Make the VTEX call here, then report what it returned.
      const id = 'vtex_8f3a2c';
      return const VtexCallResult(
          value: id,
          result: VtexResult(
              itemCount: 3,
              totalCount: 3,
              module: 'oms',
              account: 'example',
              salesChannel: 'orders',
              workspace: 'example',
              orderStatus: 'payment-pending',
              paymentStatus: 'pending',
              totalAmountMinor: 1999,
              currency: 'usd',
              cacheHit: true,
              requestId: 'request_8f3a2c',
              statusCode: 201));
    },
  );
  OTelLog.info('tracedVtex master_data.entity.create returned $vtexId');

  // Calls that should not be traced, such as health checks, run inside
  // runWithoutVtexInstrumentationAsync.
  await runWithoutVtexInstrumentationAsync(
    () => tracedVtex<String>(
      operation: 'master_data.entity.create',
      module: 'example',
      account: 'example',
      invoke: () async {
        const id = 'vtex_8f3a2c';
        return const VtexCallResult(
            value: id,
            result: VtexResult(
                itemCount: 3,
                totalCount: 3,
                module: 'oms',
                account: 'example',
                salesChannel: 'orders',
                workspace: 'example',
                orderStatus: 'payment-pending',
                paymentStatus: 'pending',
                totalAmountMinor: 1999,
                currency: 'usd',
                cacheHit: true,
                requestId: 'request_8f3a2c',
                statusCode: 201));
      },
    ),
  );

  await OTel.shutdown();
}
