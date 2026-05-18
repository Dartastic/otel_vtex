// Licensed under the Dartastic Pro Software License Agreement.
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:dartastic_opentelemetry/testing.dart';
import 'package:otel_vtex/otel_vtex.dart';
import 'package:test/test.dart';

void main() {
  late TestHarness harness;
  late InMemorySpanExporter spans;

  setUpAll(() async {
    harness = await maybeInitializeOtelForTest(
      serviceName: 'otel_vtex-test',
    );
    spans = harness.spans;
  });

  setUp(() => harness.clear());

  Map<String, Object> attrsOf(Span s) =>
      {for (final a in s.attributes.toList()) a.key: a.value};

  test('orderForm.add_item records account + sales channel', () async {
    await tracedVtex<String>(
      operation: 'checkout.orderForm.add_item',
      module: 'checkout',
      account: 'acme',
      invoke: () async => const VtexCallResult(
        value: 'ok',
        result: VtexResult(
          module: 'checkout',
          account: 'acme',
          salesChannel: '1',
          workspace: 'master',
          orderStatus: 'payment-pending',
          paymentStatus: 'pending',
          totalAmountMinor: 19990,
          currency: 'BRL',
          cacheHit: false,
          statusCode: 200,
        ),
      ),
    );
    final a = attrsOf(
      spans.findSpanByName('vtex checkout.orderForm.add_item')!,
    );
    expect(a['vtex.module'], 'checkout');
    expect(a['vtex.account'], 'acme');
    expect(a['vtex.sales_channel'], '1');
    expect(a['vtex.workspace'], 'master');
    expect(a['vtex.amount.total.minor'], 19990);
  });

  test('denied payment sets span error', () async {
    await tracedVtex<String>(
      operation: 'checkout.gateway_callback',
      invoke: () async => const VtexCallResult(
        value: 'ok',
        result: VtexResult(paymentStatus: 'denied'),
      ),
    );
    expect(
      spans.findSpanByName('vtex checkout.gateway_callback')!.status,
      SpanStatusCode.Error,
    );
  });

  test('suppression skips spans', () async {
    await runWithoutVtexInstrumentationAsync(() async {
      await tracedVtex<String>(
        operation: 'catalog.products.search',
        invoke: () async => const VtexCallResult(value: 'v'),
      );
    });
    expect(spans.findSpansStartingWith('vtex '), isEmpty);
  });
}
