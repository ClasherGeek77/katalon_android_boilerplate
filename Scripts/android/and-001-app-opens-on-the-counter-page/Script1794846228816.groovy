import static com.kms.katalon.core.testobject.ObjectRepository.findTestObject

import com.kms.katalon.core.model.FailureHandling

import android.common.FlutterInput

import com.kms.katalon.core.mobile.keyword.MobileBuiltInKeywords as Mobile

import internal.GlobalVariable as GlobalVariable

Mobile.startApplication(GlobalVariable.APK_PATH.toString(), false)
Mobile.delay(6, FailureHandling.CONTINUE_ON_FAILURE)

Mobile.verifyElementVisible(findTestObject('Object Repository/home/button_login'), 25)
Mobile.verifyElementVisible(findTestObject('Object Repository/home/txt_counter_label'), 10)

Mobile.closeApplication()
