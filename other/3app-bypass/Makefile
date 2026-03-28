TWEAK_NAME = ThreeAppBypass
ThreeAppBypass_FILES = Tweak.xm
ThreeAppBypass_FRAMEWORKS = Foundation

include $(THEOS)/makefiles/common.mk
include $(THEOS)/makefiles/tweak.mk

after-install::
	@echo "ThreeAppBypass installed"
PACKAGE_NAME = com.lara.3appbypass
PACKAGE_VERSION = 0.1
TARGET = iphone:clang:latest:latest

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = ThreeAppBypass

ThreeAppBypass_FILES = Tweak.xm

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall -9 installd || true"
