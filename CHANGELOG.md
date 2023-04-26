# Changelog

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
