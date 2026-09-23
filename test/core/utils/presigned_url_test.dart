import 'package:flutter_test/flutter_test.dart';
import 'package:yello_social_app/core/utils/presigned_url.dart';

void main() {
  test('presignedObjectKey strips the signature and keeps the object address', () {
    const a = 'https://x.r2.cloudflarestorage.com/chat-bucket/chat/44b9/photo.jpg?X-Amz-Signature=aaa&X-Amz-Expires=3600';
    const b = 'https://x.r2.cloudflarestorage.com/chat-bucket/chat/44b9/photo.jpg?X-Amz-Signature=bbb&X-Amz-Expires=3600';
    expect(presignedObjectKey(a), presignedObjectKey(b));
    expect(presignedObjectKey(a), 'https://x.r2.cloudflarestorage.com/chat-bucket/chat/44b9/photo.jpg');
  });

  test('a different object is a different key', () {
    expect(
      presignedObjectKey('https://h/chat/44b9/one.jpg?sig=1'),
      isNot(presignedObjectKey('https://h/chat/44b9/two.jpg?sig=1')),
    );
  });

  test('a port survives and a non-URL is returned unchanged', () {
    expect(presignedObjectKey('http://localhost:9000/b/o.png?sig=1'), 'http://localhost:9000/b/o.png');
    expect(presignedObjectKey('not a url'), 'not a url');
  });
}
