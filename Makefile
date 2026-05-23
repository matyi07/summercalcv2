.PHONY: ipa clean project install

project:
	xcodegen generate

ipa:
	./build.sh

install:
	./build.sh --install

clean:
	rm -rf build SummerCal.xcodeproj
