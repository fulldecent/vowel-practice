# Vowel Practice

[macOS app](https://apps.apple.com/us/app/vowel-practice/id799183655) / [iOS app](https://apps.apple.com/us/app/vowel-practice/id799183655)

Practice all the popular vowels: A, E, I, O, U and more! This app helps you with speech therapy and accent reduction.

![Vowel chart](https://github.com/user-attachments/assets/0da0e886-d6b3-4fdd-bc65-810382045125)
![Recording](https://github.com/user-attachments/assets/60c17d6e-ce56-49f2-b0ee-26e09e6566a8)

The main function of the app is you will speak individual vowel sounds (diphthongs) and the app will show you what we hear. And there is a configuration page to help get better results, this helps if you don't have professional recording gear.

Hopefully this project can help people with Val pronunciation and accent neutralization. It can be used by individuals and in a clinical setting.

## Project scope

We are seeking contributions and improvements to this program. But at the moment we are limited to implementing monophthong vowel recognition.

We will consider changes to the algorithm. However, any consideration of this must be accompanied by published papers and test data that we can replicate. See our existing model folder, and test cases!

We are also happy to accept donations of test data. If you have a large corpus of labeled data, please email us and share your experience with using this app.

We want this app to work well for an individual or a clinical setting. If there is an opportunity for a major usability improvement in these settings, let's talk about it.

## Test data

The has built-in test cases which replicate the Hillenbrand 1995 data set. Although you will need to supply those audio files and data files yourself. Instructions are in the test folder.

## Research

Here are citations and research that this app is based on.

* Speech Acoustics Made Easy <http://web.archive.org/web/20120914101638/http://www.cochlear.com/files/assets/speech_acoustics_made_easy.pdf>
* English vowel word reference <http://www.fonetiks.org/engsou2am.html>
* Chinese vowel diagram <http://en.wikipedia.org/wiki/Chinese_vowel_diagram>
* Wiki page <http://en.wikipedia.org/wiki/Formant>
* The National Center for Voice and Speech <http://www.ncvs.org/ncvs/tutorials/voiceprod/tutorial/filter.html>
* Linguistics 110 Berkeley <http://linguistics.berkeley.edu/~kjohnson/ling110/Homework_assignments/HW7_PlotVowels/PlotYourVowels.pdf>
* MATLAB Speech Signal Analysis <http://www.phon.ucl.ac.uk/courses/spsci/matlab/lect10.html>
* MATLAB Formant Tracker example <http://www.mathworks.com/matlabcentral/fileexchange/8959-formant-tracker>
* Formant Java example <http://chronos.ece.miami.edu/~dasp/SeniorProject/Presentation/416Presentation.pdf>
* Digital Bubble Bath - Don H. Johnson Great discussion on formant analysis and practical implementation <http://www.clear.rice.edu/elec431/projects96/digitalbb/formants.html>
* <https://github.com/MLSpeech/DeepFormants>
* <https://2020.ieeeicassp.org/>
* <http://htk.eng.cam.ac.uk/>
* <https://github.com/jaekookang/p2fa_py3>
* <https://github.com/gre/zpeech>

## Releasing

Use `fix:`, `feat:` or `BREAKING CHANGE:` in commit messages. Release Please opens a pull request from those. `ci:` and `chore:` do not. Merging that pull request submits iOS and macOS for App Store review. Do not edit [VERSION](VERSION) or the marketing version by hand.

Every push to `main` runs the tests and uploads an iOS build and a macOS build to TestFlight. Both go to the internal group App Store Connect Users for this app. The Apple ID has to accept the invitation before the build appears. The marketing version comes from [VERSION](VERSION). When that version is already on sale, the upload uses the next patch and does not commit it. The review submission uses the version that was uploaded. The build number is chosen at upload time and is not committed.

Store text lives in [fastlane/metadata](fastlane/metadata) and [fastlane/metadata-macos](fastlane/metadata-macos). Screenshots are generated at release time and are not committed. What's New is the newest section of [CHANGELOG.md](CHANGELOG.md).

Release Please opens its pull request as `github-actions`. GitHub holds those checks until a person approves the workflow run.

This follows [swift-app-template](https://github.com/fulldecent/swift-app-template) release 1.1.0 and the release workflow used by [8 Ball Answer](https://github.com/fulldecent/8-ball-answer).

### Setup

1. GitHub repo > Settings > Actions > General > Workflow permissions: Read and write permissions. Check "Allow GitHub Actions to create and approve pull requests".
1. Sign the Apple Developer Program agreement.
1. Repository secrets:

   * `APP_STORE_CONNECT_KEY_ID`
   * `APP_STORE_CONNECT_ISSUER_ID`
   * `APP_STORE_CONNECT_KEY`
   * `APP_STORE_DISTRIBUTION_P12`
   * `APP_STORE_DISTRIBUTION_P12_PASSWORD`
   * `APP_STORE_MAC_INSTALLER_P12`
   * `APP_STORE_MAC_INSTALLER_P12_PASSWORD`

The workflow creates the provisioning profiles at build time. The Mac package also needs the installer certificate named in [fastlane/Fastfile](fastlane/Fastfile).

App Privacy, and whether the app uses the Advertising Identifier, stay in App Store Connect. fastlane sends the encryption answer and the third-party content answer.
