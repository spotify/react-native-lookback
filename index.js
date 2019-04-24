/**  
*  Created by Sam J Thorne on 10/01/2019.
*  Copyright © 2019 Spotify AB. All rights reserved.
*  Licensed under the Apache License, Version 2.0 (the "License");
*  you may not use this file except in compliance with the License.
*  You may obtain a copy of the License at
*     http://www.apache.org/licenses/LICENSE-2.0
*  Unless required by applicable law or agreed to in writing, software
*  distributed under the License is distributed on an "AS IS" BASIS,
*  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
*  See the License for the specific language governing permissions and
*  limitations under the License.
*/

/**
 * A module for controlling Lookback from React Native
 * @module Lookback
 */
import { NativeModules, NativeEventEmitter, Linking } from "react-native";

const { LookbackBridge } = NativeModules;
const LookbackEvents = new NativeEventEmitter(LookbackBridge);

export default {
  events:
    /**
     * Register the initial listener for getting settings updates internally
     */
    LookbackEvents.addListener(LookbackBridge.updateLookbackSetting, event => {
      this.settings = { ...this.settings, ...event };
    }),
  /**
   * Set a callback to fire when Lookback starts uploading a recording
   * This only applies if you are starting the recording yourself
   * rather than the user clicking the feedback bubble
   * @type {Callback} uploadCallback - Function to execute when onStartedUpload is fired or null to clear the callback
   * @use Lookback.onStartedUpload = (upload) => console.log(upload.destinationURL, upload.sessionStartedAt);
   */
  set onStartedUpload(callback) {
    if (typeof callback == "function") {
      LookbackEvents.addListener(LookbackBridge.onStartedUpload, event => {
        callback(event);
      });
    } else if (!callback) {
      LookbackEvents.removeAllListeners(LookbackBridge.onStartedUpload);
    } else {
      console.warn(
        "onStartedUpload must be set to a function or null to clear the existing function"
      );
    }
  },
  /**
   * @callback uploadCallback
   * @param {Object} upload - Upload started event
   * @param {String} upload.destinationURL - Destination URL
   * @param {Date} upload.sessionStartedAt - Session start time
   */

  /**
   * Set a handler to listen for updates to settings from Lookback
   * @type {Callback} settingsCallback - settings callback fired when a setting is updated.
   * @use Lookback.onSettingsUpdate = (setting) => console.log(setting);
   */
  set onSettingsUpdate(settingsCallback) {
    if (typeof settingsCallback == "function") {
      this._settingsCallback = settingsCallback;
      LookbackEvents.removeAllListeners(LookbackBridge.updateLookbackSetting);
      LookbackEvents.addListener(
        LookbackBridge.updateLookbackSetting,
        event => {
          this.settings = { ...this.settings, ...event };
          if (this._settingsCallback) {
            this._settingsCallback(event);
          }
        }
      );
    } else if (!settingsCallback) {
      LookbackEvents.removeAllListeners(LookbackBridge.updateLookbackSetting);
      LookbackEvents.addListener(
        LookbackBridge.updateLookbackSetting,
        event => {
          this.settings = { ...this.settings, ...event };
        }
      );
    }
  },
  /**
   * @callback settingsCallback
   * @param {Object} setting - Key-Value pair of the updated setting
   */

  /**
   * The current settings Lookback is using.
   * These are set asynchronously, so may not be accurate all the time.
   * If you want to observe settings, register a callback for @see {@link onSettingsUpdate}
   * @type {Object} - The current settings
   * @readonly
   */
  settings: { ...LookbackBridge.settings },

  /**
   * Set up Lookback to use Lookback Participate
   * @see {@link https://lookback.io|Lookback.io}
   * @param {String} urlScheme - URL scheme specified in Lookback dashboard and in your Info.plist, usually in the format lookback-appname
   */
  setupParticipate: function(urlScheme) {
    this.settings.urlScheme = urlScheme;
    Linking.canOpenURL(`${urlScheme}://testing`).then(
      yes => {
        if (yes) {
          Linking.addEventListener("url", url => this._handleOpenURL(url));
        } else {
          console.error(
            `URL Scheme not recognised - Your application must have your url scheme, "${urlScheme}://", registered.\nIt must match the one defined in your http://lookback.io dashboard.\nSee https://developer.apple.com/documentation/uikit/core_app/allowing_apps_and_websites_to_link_to_your_content/defining_a_custom_url_scheme_for_your_app`
          );
        }
      },
      fail => {
        console.error(
          "URL Scheme Test Failed - ensure Linking is set up properly: https://facebook.github.io/react-native/docs/linking.html",
          fail
        );
      }
    );
    Linking.getInitialURL().then(
      url => {
        if (url) {
          this._handleOpenURL(url);
        }
      },
      url => console.log("URL Fetch Error", url)
    );
  },

  /**
   * Set up Lookback Recorder
   * @see {@link https://lookback.io|Lookback.io}
   * @param {String} token Lookback team token
   */
  setupWithAppToken: function(token) {
    LookbackBridge.setupWithAppToken(token);
  },

  /**
   * Set Lookback Recorder to start recording with the default options or to stop recording the current session
   * @type {Boolean} - Set Lookback to start recording or stop
   */
  set recording(isRecording) {
    LookbackBridge.recording = isRecording;
  },

  /**
   * Pause or Resume the recording
   * @type {Boolean} - set the recording to pause or not
   */
  set paused(isPaused) {
    LookbackBridge.paused = isPaused;
  },

  /**
   * Whether to show the introduction dialogs for Lookback
   * @type {Boolean} - Set the visibility of the introduction dialogs
   */
  set showIntroductionDialogs(val) {
    LookbackBridge.showIntroductionDialogs = val;
  },

  /**
   * Show or hide the Lookback Recorder UI, the equivalent to pressing the feedback bubble in app
   * @type {Boolean} setVisible - Set the visibility of the recorder
   */
  set recorderVisible(setVisible) {
    LookbackBridge.recorderVisible = setVisible;
  },

  /**
   * Show or Hide the feedback bubble
   * @type {Boolean} setVisible - Set the visibility of the bubble
   */
  set feedbackBubbleVisible(setVisible) {
    LookbackBridge.feedbackBubbleVisible(setVisible);
  },

  /**
   * Shake Device to Record
   * @type {Boolean} setShake - Enable or Disable shake device to record
   */
  set shakeToRecord(setShake) {
    LookbackBridge.shakeToRecord(setShake);
  },

  /**
   * Handle incoming links that are for Lookback Participate
   * @private
   * @param {Object} linkObject - Object passed by React Native Linking handler
   */
  _handleOpenURL(linkObject) {
    if (
      this.settings.urlScheme &&
      linkObject.url.indexOf(this.settings.urlScheme) != -1
    ) {
      LookbackBridge.openURL(linkObject.url);
    }
  }
};
