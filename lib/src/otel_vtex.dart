// Licensed under the Apache License, Version 2.0
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';

import 'otel_vtex_suppression.dart';

const _tracerName = 'dartastic_otel_libs_vtex';

APITracer _tracer() => OTelAPI.tracerProvider().getTracer(_tracerName);

class VtexResult {
  /// Creates a result.
  const VtexResult({
    this.itemCount,
    this.totalCount,
    this.module,
    this.account,
    this.salesChannel,
    this.workspace,
    this.orderStatus,
    this.paymentStatus,
    this.totalAmountMinor,
    this.currency,
    this.cacheHit,
    this.requestId,
    this.statusCode,
  });

  /// Items returned.
  final int? itemCount;

  /// `paging.total` from list endpoints.
  final int? totalCount;

  /// `oms` / `catalog` / `checkout` / `master_data` / `pricing` /
  /// `logistics` / `subscriptions` — each module has separate quotas.
  final String? module;

  /// `account` (tenant) — multi-store routing.
  final String? account;

  /// `sc` query parameter — sales channel (drives prices, stock,
  /// availability).
  final String? salesChannel;

  /// `workspace` — master / preview / staging.
  final String? workspace;

  /// `payment-pending` / `ready-for-handling` / `handling` / `invoiced`
  /// / `canceled`.
  final String? orderStatus;

  /// `pending` / `approved` / `denied` / `cancelled`.
  final String? paymentStatus;

  /// Total in minor units.
  final int? totalAmountMinor;

  /// ISO 4217.
  final String? currency;

  /// `X-VTEX-Cache: HIT|MISS` (Smartcache).
  final bool? cacheHit;

  /// `X-VTEX-OperationId` (when present).
  final String? requestId;

  final int? statusCode;
}

/// What a traced call returned: the value for the caller plus fields
/// recorded on the span.
class VtexCallResult<T> {
  /// Creates a call result.
  const VtexCallResult({required this.value, this.result});

  /// The value returned to the caller.
  final T value;
  final VtexResult? result;
}

/// Wraps a VTEX API call in a CLIENT span. [operation] is one of
/// `oms.orders.list`, `oms.orders.get`, `oms.orders.cancel`,
/// `oms.invoice`, `catalog.products.search`, `catalog.skus.get`,
/// `checkout.orderForm.get`, `checkout.orderForm.add_item`,
/// `checkout.gateway_callback`, `master_data.search`,
/// `master_data.entity.create`, `pricing.compute`,
/// `logistics.inventory.list`, `subscriptions.list`.
Future<T> tracedVtex<T>({
  required String operation,
  required Future<VtexCallResult<T>> Function() invoke,
  String? module,
  String? account,
}) async {
  if (vtexInstrumentationSuppressed()) {
    final r = await invoke();
    return r.value;
  }
  final m = <String, Object>{
    'rpc.system': 'vtex',
    'rpc.method': operation,
    'vtex.operation': operation,
  };
  if (module != null) m['vtex.module'] = module;
  if (account != null) m['vtex.account'] = account;

  final span = _tracer().startSpan(
    'vtex $operation',
    kind: SpanKind.client,
    attributes: OTelAPI.attributesFromMap(m),
  );
  try {
    final r = await invoke();
    if (r.result != null) {
      final extras = <Attribute<Object>>[];
      if (r.result!.itemCount != null) {
        extras.add(OTelAPI.attributeInt(
          'vtex.item_count',
          r.result!.itemCount!,
        ));
      }
      if (r.result!.totalCount != null) {
        extras.add(OTelAPI.attributeInt(
          'vtex.total_count',
          r.result!.totalCount!,
        ));
      }
      if (r.result!.module != null) {
        extras.add(OTelAPI.attributeString('vtex.module', r.result!.module!));
      }
      if (r.result!.account != null) {
        extras.add(OTelAPI.attributeString(
          'vtex.account',
          r.result!.account!,
        ));
      }
      if (r.result!.salesChannel != null) {
        extras.add(OTelAPI.attributeString(
          'vtex.sales_channel',
          r.result!.salesChannel!,
        ));
      }
      if (r.result!.workspace != null) {
        extras.add(OTelAPI.attributeString(
          'vtex.workspace',
          r.result!.workspace!,
        ));
      }
      if (r.result!.orderStatus != null) {
        extras.add(OTelAPI.attributeString(
          'vtex.order.status',
          r.result!.orderStatus!,
        ));
        if (r.result!.orderStatus == 'canceled') {
          span.setStatus(
            SpanStatusCode.Error,
            'VTEX order canceled',
          );
        }
      }
      if (r.result!.paymentStatus != null) {
        extras.add(OTelAPI.attributeString(
          'vtex.payment.status',
          r.result!.paymentStatus!,
        ));
        if (r.result!.paymentStatus == 'denied') {
          span.setStatus(
            SpanStatusCode.Error,
            'VTEX payment denied',
          );
        }
      }
      if (r.result!.totalAmountMinor != null) {
        extras.add(OTelAPI.attributeInt(
          'vtex.amount.total.minor',
          r.result!.totalAmountMinor!,
        ));
      }
      if (r.result!.currency != null) {
        extras.add(OTelAPI.attributeString(
          'vtex.currency',
          r.result!.currency!,
        ));
      }
      if (r.result!.cacheHit != null) {
        extras.add(OTelAPI.attributeBool(
          'vtex.cache.hit',
          r.result!.cacheHit!,
        ));
      }
      if (r.result!.requestId != null) {
        extras.add(OTelAPI.attributeString(
          'vtex.request.id',
          r.result!.requestId!,
        ));
      }
      if (r.result!.statusCode != null) {
        extras.add(OTelAPI.attributeInt(
          'http.response.status_code',
          r.result!.statusCode!,
        ));
        if (r.result!.statusCode! >= 400) {
          span.setStatus(
            SpanStatusCode.Error,
            'VTEX HTTP ${r.result!.statusCode}',
          );
        }
      }
      if (extras.isNotEmpty) span.addAttributes(OTelAPI.attributes(extras));
    }
    return r.value;
  } catch (e, st) {
    span.addAttributes(OTelAPI.attributes([
      OTelAPI.attributeString(
        ErrorAttributes.errorType.key,
        e.runtimeType.toString(),
      ),
    ]));
    span.recordException(e, stackTrace: st);
    span.setStatus(SpanStatusCode.Error, e.toString());
    rethrow;
  } finally {
    span.end();
  }
}
