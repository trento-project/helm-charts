# Changelog

## [3.0.1](https://github.com/trento-project/helm-charts/tree/3.0.1) (2026-01-15)

[Full Changelog](https://github.com/trento-project/helm-charts/compare/3.0.0...3.0.1)

### Fixed

- Make values of alerting settings as strings in ConfigMap [\#166](https://github.com/trento-project/helm-charts/pull/166) (@skrech)

### Other Changes

- Bump actions/download-artifact from 6 to 7 [\#164](https://github.com/trento-project/helm-charts/pull/164) (@dependabot[bot])
- Bump actions/upload-artifact from 5 to 6 [\#163](https://github.com/trento-project/helm-charts/pull/163) (@dependabot[bot])

## [3.0.0](https://github.com/trento-project/helm-charts/tree/3.0.0) (2025-11-26)

[Full Changelog](https://github.com/trento-project/helm-charts/compare/2.5.0...3.0.0)

### Added

- Rewrite introspect endpoint [\#157](https://github.com/trento-project/helm-charts/pull/157) (@nelsonkopliku)
- Adjust chart version [\#155](https://github.com/trento-project/helm-charts/pull/155) (@nelsonkopliku)
- Add extra AUTH\_SERVER\_URL env to wanda [\#150](https://github.com/trento-project/helm-charts/pull/150) (@nelsonkopliku)
- \[TRNT-3845\] Add missing values in the values.yaml files [\#146](https://github.com/trento-project/helm-charts/pull/146) (@antgamdia)
- Update wanda ingress add OAS\_SERVER\_URL usage [\#145](https://github.com/trento-project/helm-charts/pull/145) (@arbulu89)

### Fixed

- \[TRNT-3854\] Fix typo in mcp-server chart [\#154](https://github.com/trento-project/helm-charts/pull/154) (@antgamdia)
- Fix trento web origin usage loading the correct value [\#153](https://github.com/trento-project/helm-charts/pull/153) (@arbulu89)
- Fix broken link in README [\#138](https://github.com/trento-project/helm-charts/pull/138) (@EMaksy)
- Make rabbitmq configmap name dynamic [\#136](https://github.com/trento-project/helm-charts/pull/136) (@nelsonkopliku)

### Removed

- Remove jwt secrets from wanda [\#158](https://github.com/trento-project/helm-charts/pull/158) (@nelsonkopliku)

### Other Changes

- Bump actions/checkout from 5 to 6 [\#161](https://github.com/trento-project/helm-charts/pull/161) (@dependabot[bot])
- \[TRNT-3854\] Improve notes [\#160](https://github.com/trento-project/helm-charts/pull/160) (@antgamdia)
- Bump helm/chart-testing-action from 2.7.0 to 2.8.0 [\#159](https://github.com/trento-project/helm-charts/pull/159) (@dependabot[bot])
- Fix erlang cookie permissions [\#156](https://github.com/trento-project/helm-charts/pull/156) (@balanza)
- Use ingress className instead of annotation [\#149](https://github.com/trento-project/helm-charts/pull/149) (@arbulu89)
- Bump actions/upload-artifact from 4 to 5 [\#148](https://github.com/trento-project/helm-charts/pull/148) (@dependabot[bot])
- Bump actions/download-artifact from 4 to 6 [\#147](https://github.com/trento-project/helm-charts/pull/147) (@dependabot[bot])
- Use official Rabbitmq image [\#144](https://github.com/trento-project/helm-charts/pull/144) (@balanza)
- \[TRNT-3854\] Add initial MCP Server chart [\#143](https://github.com/trento-project/helm-charts/pull/143) (@antgamdia)
- Bump actions/setup-python from 5 to 6 [\#142](https://github.com/trento-project/helm-charts/pull/142) (@dependabot[bot])
- Prepare docs for auto build [\#141](https://github.com/trento-project/helm-charts/pull/141) (@EMaksy)
- Bump actions/checkout from 4 to 5 [\#140](https://github.com/trento-project/helm-charts/pull/140) (@dependabot[bot])
- Convert Markdown to Adoc [\#137](https://github.com/trento-project/helm-charts/pull/137) (@EMaksy)
- Setup rabbitmq tls [\#135](https://github.com/trento-project/helm-charts/pull/135) (@balanza)
- Updated defaults for alerting settings [\#131](https://github.com/trento-project/helm-charts/pull/131) (@skrech)

## [2.5.0](https://github.com/trento-project/helm-charts/tree/2.5.0) (2025-07-01)

### What's Changed

* update license notice and replace README section with a link by @stefanotorresi in https://github.com/trento-project/helm-charts/pull/121
* adjust new wanda endpoints by @nelsonkopliku in https://github.com/trento-project/helm-charts/pull/124
* Add operations endpoint ingress rule by @arbulu89 in https://github.com/trento-project/helm-charts/pull/126
* Upgrade github actions runner ubuntu version by @arbulu89 in https://github.com/trento-project/helm-charts/pull/127
* Bump wanda charts by @nelsonkopliku in https://github.com/trento-project/helm-charts/pull/128
* Add operation api paths to cert manager guideline by @arbulu89 in https://github.com/trento-project/helm-charts/pull/129
* Add CODEOWNERS by @nelsonkopliku in https://github.com/trento-project/helm-charts/pull/130
* Small fixes on the install script by @balanza in https://github.com/trento-project/helm-charts/pull/125

#### Dependencies

<details>
<summary>5 changes</summary>
* Bump azure/setup-helm from 3.5 to 4 by @dependabot in https://github.com/trento-project/helm-charts/pull/110
* Bump actions/setup-python from 4 to 5 by @dependabot in https://github.com/trento-project/helm-charts/pull/85
* Bump helm/chart-releaser-action from 1.5.0 to 1.6.0 by @dependabot in https://github.com/trento-project/helm-charts/pull/80
* Bump helm/chart-testing-action from 2.6.1 to 2.7.0 by @dependabot in https://github.com/trento-project/helm-charts/pull/122
* Bump helm/chart-releaser-action from 1.6.0 to 1.7.0 by @dependabot in https://github.com/trento-project/helm-charts/pull/123
</details>

**Full Changelog**: https://github.com/trento-project/helm-charts/compare/2.4.1...2.5.0


## [2.4.0](https://github.com/trento-project/helm-charts/tree/2.4.0) (2024-11-12)

[Full Changelog](https://github.com/trento-project/helm-charts/compare/2.3.2...2.4.0)

### Added

- Fix typo in variable usage [\#113](https://github.com/trento-project/helm-charts/pull/113) (@arbulu89)
- Make secret key base configurable [\#112](https://github.com/trento-project/helm-charts/pull/112) (@arbulu89)
- Add SAML integration [\#106](https://github.com/trento-project/helm-charts/pull/106) (@arbulu89)
- Add OAUTH2 usage [\#105](https://github.com/trento-project/helm-charts/pull/105) (@arbulu89)
- Add an argument to the install script for username [\#100](https://github.com/trento-project/helm-charts/pull/100) (@bear454)

### Other Changes

- Change saml.spDir default location [\#115](https://github.com/trento-project/helm-charts/pull/115) (@arbulu89)
- Update values-overwrite.yaml [\#111](https://github.com/trento-project/helm-charts/pull/111) (@dottorblaster)
- Fix checks image tag [\#109](https://github.com/trento-project/helm-charts/pull/109) (@dottorblaster)
- make version check less brittle and more relaxed [\#108](https://github.com/trento-project/helm-charts/pull/108) (@stefanotorresi)
- remove support script [\#107](https://github.com/trento-project/helm-charts/pull/107) (@stefanotorresi)
- Add init-container for checks deployment [\#104](https://github.com/trento-project/helm-charts/pull/104) (@janvhs)
- Add OIDC usage [\#103](https://github.com/trento-project/helm-charts/pull/103) (@arbulu89)
- Bump actions/upload-artifact from 3 to 4 [\#87](https://github.com/trento-project/helm-charts/pull/87) (@dependabot[bot])
- Bump actions/download-artifact from 3 to 4 [\#86](https://github.com/trento-project/helm-charts/pull/86) (@dependabot[bot])
- Bump helm/chart-testing-action from 2.6.0 to 2.6.1 [\#81](https://github.com/trento-project/helm-charts/pull/81) (@dependabot[bot])

## [2.3.2](https://github.com/trento-project/helm-charts/tree/2.3.2) (2024-07-24)

[Full Changelog](https://github.com/trento-project/helm-charts/compare/2.3.1...2.3.2)

### Other Changes

- Update chart to use trento-web 2.3.2 version (@arbulu89)

## [2.3.1](https://github.com/trento-project/helm-charts/tree/2.3.1) (2024-06-10)

[Full Changelog](https://github.com/trento-project/helm-charts/compare/2.3.0...2.3.1)

### Other Changes

- Rename `TRENTO_DOMAIN` to `TRENTO_WEB_ORIGIN` [\#97](https://github.com/trento-project/helm-charts/pull/97) (@nelsonkopliku)
- Add TRENTO\_DOMAIN env var [\#96](https://github.com/trento-project/helm-charts/pull/96) (@rtorrero)
- Add cert manager support [\#95](https://github.com/trento-project/helm-charts/pull/95) (@rtorrero)
- Add env var support for the supportconfig plugin/wrapper [\#83](https://github.com/trento-project/helm-charts/pull/83) (@rtorrero)

## [2.3.0](https://github.com/trento-project/helm-charts/tree/2.3.0) (2024-05-13)

[Full Changelog](https://github.com/trento-project/helm-charts/compare/2.2.0...2.3.0)

### Added

- Add v3 checks path to the ingress configuration [\#93](https://github.com/trento-project/helm-charts/pull/93) (@arbulu89)
- Postgres database creation with INIT containers [\#91](https://github.com/trento-project/helm-charts/pull/91) (@CDimonaco)
- Add option to disable charts [\#89](https://github.com/trento-project/helm-charts/pull/89) (@arbulu89)

### Fixed

- Add wanda v2 apis in ingress [\#84](https://github.com/trento-project/helm-charts/pull/84) (@nelsonkopliku)

### Removed

- Remove grafana [\#88](https://github.com/trento-project/helm-charts/pull/88) (@arbulu89)

### Other Changes

- Update license to the year 2024 [\#92](https://github.com/trento-project/helm-charts/pull/92) (@EMaksy)
- Update LICENSE [\#90](https://github.com/trento-project/helm-charts/pull/90) (@stefanotorresi)

## [2.2.0](https://github.com/trento-project/helm-charts/tree/2.2.0) (2023-11-14)

[Full Changelog](https://github.com/trento-project/helm-charts/compare/2.1.0...2.2.0)

### Added

- Add namespace option [\#77](https://github.com/trento-project/helm-charts/pull/77) (@rtorrero)
- Make pruning crobjob days variable [\#76](https://github.com/trento-project/helm-charts/pull/76) (@arbulu89)
- Wanda rollout [\#74](https://github.com/trento-project/helm-charts/pull/74) (@nelsonkopliku)

### Fixed

- Enable rolling releases for script packages in OBS [\#78](https://github.com/trento-project/helm-charts/pull/78) (@rtorrero)

### Other Changes

- Bump helm/chart-testing-action from 2.4.0 to 2.6.0 [\#79](https://github.com/trento-project/helm-charts/pull/79) (@dependabot[bot])
- Bump actions/checkout from 3 to 4 [\#75](https://github.com/trento-project/helm-charts/pull/75) (@dependabot[bot])
- Bump helm/chart-testing-action from 2.3.1 to 2.4.0 [\#70](https://github.com/trento-project/helm-charts/pull/70) (@dependabot[bot])

## [2.1.0](https://github.com/trento-project/helm-charts/tree/2.1.0) (2023-08-02)

[Full Changelog](https://github.com/trento-project/helm-charts/compare/2.0.0...2.1.0)

### Other Changes

- Update copyright year to 2023 [\#72](https://github.com/trento-project/helm-charts/pull/72) (@EMaksy)

## [2.0.0](https://github.com/trento-project/helm-charts/tree/2.0.0) (2023-04-26)

[Full Changelog](https://github.com/trento-project/helm-charts/compare/1.2.0...2.0.0)

### Added

- Disable cors usage for wanda [\#69](https://github.com/trento-project/helm-charts/pull/69) (@arbulu89)
- Add a temporary fix to wanda ingress path value to use versioning [\#65](https://github.com/trento-project/helm-charts/pull/65) (@arbulu89)
- Add new name flag to supportconfig script [\#64](https://github.com/trento-project/helm-charts/pull/64) (@arbulu89)
- Update support script with wanda [\#63](https://github.com/trento-project/helm-charts/pull/63) (@fabriziosestito)
- Update installation script for wanda [\#61](https://github.com/trento-project/helm-charts/pull/61) (@arbulu89)
- Replace legacy runner by wanda [\#58](https://github.com/trento-project/helm-charts/pull/58) (@fabriziosestito)
- Add the env variables for new authentication system of trento-web project [\#57](https://github.com/trento-project/helm-charts/pull/57) (@CDimonaco)
- Include postgresql chart [\#55](https://github.com/trento-project/helm-charts/pull/55) (@fabriziosestito)

### Fixed

- Fix shared access token key usage [\#67](https://github.com/trento-project/helm-charts/pull/67) (@arbulu89)
- Provision postgresql data folder permissions [\#59](https://github.com/trento-project/helm-charts/pull/59) (@arbulu89)
- Fix wrong -dev suffix in trento-server BuildTag [\#50](https://github.com/trento-project/helm-charts/pull/50) (@rtorrero)

### Removed

- Remove runner references from docs [\#62](https://github.com/trento-project/helm-charts/pull/62) (@fabriziosestito)

### Other Changes

- Bump actions/checkout from 2 to 3 [\#68](https://github.com/trento-project/helm-charts/pull/68) (@dependabot[bot])
- Bump helm/chart-releaser-action from 1.4.1 to 1.5.0 [\#56](https://github.com/trento-project/helm-charts/pull/56) (@dependabot[bot])
- Bump postgresql chart version to 12.1.6 [\#53](https://github.com/trento-project/helm-charts/pull/53) (@fabriziosestito)
- Bump azure/setup-helm from 3.3 to 3.5 [\#52](https://github.com/trento-project/helm-charts/pull/52) (@dependabot[bot])
- Switch + sign for - in build metadata [\#51](https://github.com/trento-project/helm-charts/pull/51) (@rtorrero)
- Bump helm/chart-testing-action from 2.3.0 to 2.3.1 [\#41](https://github.com/trento-project/helm-charts/pull/41) (@dependabot[bot])
- Bump helm/chart-releaser-action from 1.4.0 to 1.4.1 [\#40](https://github.com/trento-project/helm-charts/pull/40) (@dependabot[bot])

## [1.2.0](https://github.com/trento-project/helm-charts/tree/1.2.0) (2022-11-04)

[Full Changelog](https://github.com/trento-project/helm-charts/compare/1.1.0...1.2.0)

### Fixed

- Add gh\_release file to fix the CI process [\#36](https://github.com/trento-project/helm-charts/pull/36) (@arbulu89)

### Other Changes

- Cleanup debugging leftovers supportconfig specfile [\#48](https://github.com/trento-project/helm-charts/pull/48) (@rtorrero)
- fix workflow name [\#47](https://github.com/trento-project/helm-charts/pull/47) (@gereonvey)
- update obs related CI jobs [\#45](https://github.com/trento-project/helm-charts/pull/45) (@stefanotorresi)
- Fixes in trento-support about compressed output [\#44](https://github.com/trento-project/helm-charts/pull/44) (@mpagot)
- Initial work to add  wanda container [\#43](https://github.com/trento-project/helm-charts/pull/43) (@rtorrero)
- Add basic rabbitmq chart [\#42](https://github.com/trento-project/helm-charts/pull/42) (@arbulu89)
- Update grafana chart dependency to 6.36.1 [\#39](https://github.com/trento-project/helm-charts/pull/39) (@rtorrero)
- Bump helm/chart-testing-action from 2.2.1 to 2.3.0 [\#38](https://github.com/trento-project/helm-charts/pull/38) (@dependabot[bot])
- Bump azure/setup-helm from 2.1 to 3.3 [\#37](https://github.com/trento-project/helm-charts/pull/37) (@dependabot[bot])
- Add basic script for support requests [\#32](https://github.com/trento-project/helm-charts/pull/32) (@rtorrero)

## [1.1.0](https://github.com/trento-project/helm-charts/tree/1.1.0) (2022-07-14)

[Full Changelog](https://github.com/trento-project/helm-charts/compare/1.0.0...1.1.0)

### Added

- Change trento-premium-server-installer to be obsolete in the spec [\#33](https://github.com/trento-project/helm-charts/pull/33) (@rtorrero)
- Allow setting a custom sender for alerting notification emails [\#31](https://github.com/trento-project/helm-charts/pull/31) (@nelsonkopliku)
- Add prometheus url env variable [\#24](https://github.com/trento-project/helm-charts/pull/24) (@fabriziosestito)
- Split web runner version usage [\#23](https://github.com/trento-project/helm-charts/pull/23) (@arbulu89)
- Improve CI to update change file on release and fix version string generation [\#21](https://github.com/trento-project/helm-charts/pull/21) (@arbulu89)

### Fixed

- Downgrade postgresql chart 10 [\#26](https://github.com/trento-project/helm-charts/pull/26) (@arbulu89)
- Upgrade bitnami postgresql chart version to 11.x.x [\#25](https://github.com/trento-project/helm-charts/pull/25) (@arbulu89)
- Fix syntax error in gihtub ci file introduced in last PR [\#22](https://github.com/trento-project/helm-charts/pull/22) (@arbulu89)

### Closed Issues

- Can't get valid version postgresql. [\#29](https://github.com/trento-project/helm-charts/issues/29)
- Complete newbie: not listening on port 80 after installation [\#28](https://github.com/trento-project/helm-charts/issues/28)

### Other Changes

- Bump actions/setup-python from 3 to 4 [\#27](https://github.com/trento-project/helm-charts/pull/27) (@dependabot[bot])

## [1.0.0](https://github.com/trento-project/helm-charts/tree/1.0.0) (2022-04-29)

[Full Changelog](https://github.com/trento-project/helm-charts/compare/trento-server-0.4.4-dev...1.0.0)

### Closed Issues

- forward port trento\#912 [\#7](https://github.com/trento-project/helm-charts/issues/7)

### Other Changes

- Bump images to 1.0.0 [\#20](https://github.com/trento-project/helm-charts/pull/20) (@dottorblaster)
- Trento server installer [\#18](https://github.com/trento-project/helm-charts/pull/18) (@arbulu89)
- Restore prune events job [\#17](https://github.com/trento-project/helm-charts/pull/17) (@fabriziosestito)
- add license identifier and bump chart version [\#16](https://github.com/trento-project/helm-charts/pull/16) (@stefanotorresi)
- fix setting of admin password in install-server.sh [\#15](https://github.com/trento-project/helm-charts/pull/15) (@gereonvey)
- Suse delivery [\#14](https://github.com/trento-project/helm-charts/pull/14) (@arbulu89)
- Add admin user initialization [\#13](https://github.com/trento-project/helm-charts/pull/13) (@fabriziosestito)
- Remove mtls references [\#12](https://github.com/trento-project/helm-charts/pull/12) (@fabriziosestito)
- Bump azure/setup-helm from 2.0 to 2.1 [\#11](https://github.com/trento-project/helm-charts/pull/11) (@dependabot[bot])
- Bump actions/download-artifact from 2 to 3 [\#10](https://github.com/trento-project/helm-charts/pull/10) (@dependabot[bot])
- Bump actions/upload-artifact from 2 to 3 [\#9](https://github.com/trento-project/helm-charts/pull/9) (@dependabot[bot])
- add trento-server.sh installer options for advanced use [\#8](https://github.com/trento-project/helm-charts/pull/8) (@gereonvey)
- Update helm chart for the new containers [\#6](https://github.com/trento-project/helm-charts/pull/6) (@fabriziosestito)
- Add grafana env variables [\#5](https://github.com/trento-project/helm-charts/pull/5) (@fabriziosestito)
- Add support for optional Alerting configs [\#4](https://github.com/trento-project/helm-charts/pull/4) (@nelsonkopliku)
- New trento dashboard [\#3](https://github.com/trento-project/helm-charts/pull/3) (@fabriziosestito)
- Bump helm/chart-releaser-action from 1.2.1 to 1.4.0 [\#2](https://github.com/trento-project/helm-charts/pull/2) (@dependabot[bot])


\* *This Changelog was automatically generated by [github_changelog_generator](https://github.com/github-changelog-generator/github-changelog-generator)*
