# feat: add initial dashboard screen with placeholder dropdown and navigation to cattle list

## Kontekst i cilj
Nakon logina aplikacija trenutno vodi direktno na listu goveda. Cilj je uvesti pocetni dashboard koji ce biti centralna tocka za buduće opcije i ulaze u feature tokove.

## UX opis
- Nakon uspjesnog logina korisnik vidi `Pocetni dashboard`.
- Dashboard sadrzi padajuci meni (`Brzi odabir`) s lokalnim placeholder opcijama:
  - `Odaberi opciju`
  - `Opcija A`
  - `Opcija B`
- Dashboard sadrzi primarni gumb `Goveda` koji otvara `CattleListScreen`.
- Dodatni gumbi su prikazani kao disabled placeholderi za buduce funkcije.
- `Logout` akcija ostaje dostupna iz app bara dashboarda.

## Tehnicke izmjene
- Dodati novi screen: `DashboardScreen`.
- Promijeniti post-login routing:
  - bez tokena -> `LoginScreen`
  - s tokenom -> `DashboardScreen`
- `DashboardScreen` prima i prosljeduje postojece dependencyje za otvaranje `CattleListScreen`:
  - `FarmsRepository`
  - `CattleRepository`
  - `UploadRepository`
  - `onLogout`

## Acceptance kriteriji
- [ ] Korisnik bez tokena vidi login ekran.
- [ ] Korisnik s tokenom vidi dashboard ekran.
- [ ] Dashboard prikazuje placeholder dropdown i gumb `Goveda`.
- [ ] Klik na `Goveda` otvara `CattleListScreen`.
- [ ] Logout s dashboarda cisti sesiju i vraca korisnika na login.
- [ ] Postojeći tokovi liste goveda i uploada rade bez regresije.

## Test checklist
- [ ] Widget test: dashboard render (dropdown + gumb `Goveda`).
- [ ] Widget/integration flow: login -> dashboard -> cattle list -> upload.
- [ ] App routing test: token/no-token preusmjeravanje.

## Out of scope (v1)
- Punjenje dashboard dropdowna podacima s backenda.
- Persistencija dashboard odabira.
- Dodavanje novih funkcionalnih dashboard akcija osim ulaza u `CattleListScreen`.
