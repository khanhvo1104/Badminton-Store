import 'package:base_project/core/errors/app_exception.dart';
import 'package:base_project/core/errors/error_mapper.dart';
import 'package:base_project/core/logging/app_logger.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ErrorMapper mapper;

  setUp(() {
    mapper = ErrorMapper(AppLogger());
  });

  test('passes through AppException', () {
    const original = UnauthorizedException('denied');
    expect(mapper.map(original), same(original));
  });

  test('maps connection timeout to NetworkException', () {
    final mapped = mapper.map(
      DioException(
        requestOptions: RequestOptions(),
        type: DioExceptionType.connectionTimeout,
      ),
    );
    expect(mapped, isA<NetworkException>());
  });

  test('maps 401 to UnauthorizedException', () {
    final mapped = mapper.map(
      DioException(
        requestOptions: RequestOptions(),
        type: DioExceptionType.badResponse,
        response: Response(requestOptions: RequestOptions(), statusCode: 401),
      ),
    );
    expect(mapped, isA<UnauthorizedException>());
  });

  test('maps 403 to UnauthorizedException with permission message', () {
    final mapped = mapper.map(
      DioException(
        requestOptions: RequestOptions(),
        type: DioExceptionType.badResponse,
        response: Response(requestOptions: RequestOptions(), statusCode: 403),
      ),
    );
    expect(mapped, isA<UnauthorizedException>());
    expect(mapped.message.toLowerCase(), contains('permission'));
  });

  test('maps 500 to ServerException', () {
    final mapped = mapper.map(
      DioException(
        requestOptions: RequestOptions(),
        type: DioExceptionType.badResponse,
        response: Response(requestOptions: RequestOptions(), statusCode: 500),
      ),
    );
    expect(mapped, isA<ServerException>());
    expect((mapped as ServerException).statusCode, 500);
  });

  test('maps unknown errors to UnknownException', () {
    final mapped = mapper.map(StateError('unexpected'));
    expect(mapped, isA<UnknownException>());
  });
}
