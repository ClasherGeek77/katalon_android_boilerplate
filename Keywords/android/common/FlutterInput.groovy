package android.common

import com.kms.katalon.core.appium.driver.AppiumDriverManager
import com.kms.katalon.core.testobject.TestObject
import io.appium.java_client.TouchAction
import io.appium.java_client.android.AndroidDriver
import io.appium.java_client.touch.WaitOptions
import io.appium.java_client.touch.offset.PointOption
import org.openqa.selenium.By
import org.openqa.selenium.Dimension
import org.openqa.selenium.InvalidElementStateException
import org.openqa.selenium.Point
import org.openqa.selenium.WebElement
import org.openqa.selenium.support.ui.ExpectedConditions
import org.openqa.selenium.support.ui.WebDriverWait

import java.time.Duration

/**
 * text into a flutter field the way ../pytest_boilerplate_android proved:
 * sendKeys is refused on the accessibility node (InvalidElementStateException)
 * and this device has no IME attached, so paste it — long press (TouchAction,
 * driver.tap stopped registering on fresh boots) opens the edit toolbar, the
 * clipboard carries the value, and the toolbar closing proves the paste took.
 */
public class FlutterInput {

	// the only custom call left in the suite: flutter fields here reject
	// Mobile.setText (InvalidElementStateException, no IME on the AVD), so
	// typing stays this one keyword — it reads the locator straight from an
	// Object Repository .rs via findTestObject, everything else is built-in.
	private static String xpathOf(TestObject to) {
		if (to instanceof com.kms.katalon.core.testobject.MobileTestObject) {
			String ml = to.getMobileLocator()
			if (ml != null && !ml.isEmpty()) {
				return ml
			}
		}
		String v = to.getSelectorCollection().get(to.getSelectorMethod())
		if (v == null || v.isEmpty()) {
			v = to.findPropertyValue("xpath")
		}
		return v
	}

	static void type(TestObject to, String value) {
		String xpath = xpathOf(to)
		AndroidDriver<?> driver = (AndroidDriver<?>) AppiumDriverManager.getDriver()
		WebElement field = new WebDriverWait(driver, 20).until(
				ExpectedConditions.presenceOfElementLocated(By.xpath(xpath)))
		field.click()
		try {
			field.sendKeys(value)
		} catch (InvalidElementStateException ignored) {
			pasteInto(driver, field, value)
		}
	}

	private static void pasteInto(AndroidDriver<?> driver, WebElement field, String value) {
		Point loc = field.getLocation()
		Dimension sz = field.getSize()
		Point center = new Point(loc.getX() + sz.getWidth().intdiv(2),
				loc.getY() + sz.getHeight().intdiv(2))
		TouchAction<?> ta = new TouchAction<>(driver)
		ta.press(PointOption.point(center))
				.waitAction(WaitOptions.waitOptions(Duration.ofSeconds(2)))
				.release()
				.perform()
		WebElement paste = new WebDriverWait(driver, 20).until(
				ExpectedConditions.presenceOfElementLocated(By.xpath("//*[@content-desc='Paste']")))
		driver.setClipboardText(value)
		paste.click()
		new WebDriverWait(driver, 20).until(
				ExpectedConditions.invisibilityOfElementLocated(By.xpath("//*[@content-desc='Paste']")))
	}
}
