# Contests and Conflict Networks: Theory and an Application to Sudan

Code, data and supporting documents for a network study of the Sudan civil wars (2003–2010). The main paper is [Sudan_Conflict_MainPaper.pdf](Sudan_Conflict_MainPaper.pdf).

The project applies a network theory of conflict to Sudan. Alliances and enmities among 102 armed groups form a signed network, and each group's fighting effort and share of contested resources depend on the efforts of its allies and enemies. Using ACLED event-level data and a generalized Tullock contest framework, the paper derives and estimates a structural equation in which equilibrium fighting effort is pinned down by each group's network centrality. The framework follows König et al. (2017).

**This repository contains the empirical groundwork.** The R script builds friendship and enmity matrices from ACLED events and computes the centrality measures the model uses. It also includes an interactive map of events and a historical context document.

| Matrix | Edge rule | Actors | Edges |
|---|---|---|---|
| Enmity | Appeared as `actor1` vs `actor2` in at least one event | 51 | 52 |
| Friendship | Appeared as an actor and its associated actor on the same side at least once | 51 | 12 |
| Resultant (signed) | Friendship minus enmity: `+1` ally, `−1` enemy, `0` none or both | 51 | 63 |

The network data covers 199 ACLED battle events in Sudan from 24 January 2003 to 28 December 2011.

---

## Repository layout

```
.
├── Sudan_Conflict_MainPaper.pdf        # main paper (Fernandes, Melo, Rubbini & Centorrino)
├── Konig et al. (2017).pdf             # theoretical framework
├── Provenzano & Bull.pdf               # related methodology (mining and local development)
├── sudan_data_analysis/
│   ├── Econ_Research.Rproj             # RStudio project; sets the working directory
│   ├── Mapping.R                       # map, matrices and centralities
│   ├── 2003-01-01-2011-12-31-Northern_Africa-Sudan.csv          # ACLED, 199 events (used by Mapping.R)
│   ├── 1997-01-01-2024-09-30-Northern_Africa-South_Sudan-Sudan.csv  # ACLED, 8,004 events (not used yet)
│   ├── data/                           # copies of the two CSVs above
│   ├── Friendship_matrix.xlsx          # output of Mapping.R
│   ├── Enmity_matrix.xlsx              # output of Mapping.R
│   ├── Resultant_matrix.xlsx           # output of Mapping.R
│   └── code_validity_check.pdf         # hand-checked examples for each centrality
└── sudan_historical_context/
    ├── hist_context_sudan_war.tex      # historical context, British rule to the civil wars
    ├── hist_context_sudan_war.pdf
    ├── references.bib
    └── figures/
```

---

## 1. Environment setup

The code is written in **R** and is easiest to run in RStudio. Open [sudan_data_analysis/Econ_Research.Rproj](sudan_data_analysis/Econ_Research.Rproj) so that the working directory is `sudan_data_analysis/`. `Mapping.R` reads the CSV by relative path.

The first lines of `Mapping.R` install every package. After the first run, comment them out.

| Package | Used for |
|---|---|
| sf, tmap, spData, maps | interactive map of events |
| igraph | betweenness centrality, network plots |
| sna | Bonacich power centrality (`bonpow`) |
| dplyr, tidyverse, reshape2 | data handling |
| openxlsx, writexl | Excel export |
| ggplot2, gmodels | loaded, not essential |

`spDataLarge` is installed from `https://nowosad.github.io/drat/` and needs a build toolchain (Rtools on Windows). The script does not use it, so the line can be skipped.

---

## 2. Run the analysis

Run [sudan_data_analysis/Mapping.R](sudan_data_analysis/Mapping.R) top to bottom. Its sections are independent of each other except that all of them need `Sud_df` and the matrices.

| Section | Output |
|---|---|
| Interactive map | Map of event locations in the RStudio Viewer (`tmap_mode("view")`, OpenStreetMap basemap) |
| Relationship matrices | `Friendship_matrix.xlsx`, `Enmity_matrix.xlsx`, `Resultant_matrix.xlsx`, written to `sudan_data_analysis/` |
| Centralities | `cent_mat`, a 51 × 7 matrix in the R session (not saved to disk) |
| Visualization | Two `igraph` plots of the unsigned network |

To save the centralities, add for example

```r
write.xlsx(as.data.frame(cent_mat), "Centralities.xlsx", rowNames = TRUE)
```

---

## 3. What the code does

### Events

`Mapping.R` uses every row of `2003-01-01-2011-12-31-Northern_Africa-Sudan.csv`. All 199 events are of type **Battles** and located in Sudan. Actors are taken from `actor1`, `assoc_actor_1`, `actor2` and `assoc_actor_2`. Empty names are dropped, which leaves **51** actors. No actor is excluded by type.

### Matrices

- **Enmity.** For each event, `actor1` and `actor2` are enemies. Associated actors are not linked to the opposing side. Events where `actor1` and `actor2` are the same (3 events) are skipped.
- **Friendship.** For each event, `actor1` and `assoc_actor_1` are allies, and so are `actor2` and `assoc_actor_2`.
- **Resultant.** `friendship − enmity`. One pair is both allied and hostile, so it gets `0`.

All matrices are binary and symmetric. The number of events behind a tie is not recorded.

### Centralities

All measures except the last use the unsigned network (every `−1` in the resultant matrix set to `1`).

| Measure | Implementation |
|---|---|
| Degree | Number of links divided by `n − 1`. From scratch. |
| Closeness | Shortest paths found from powers of the adjacency matrix, up to length 5. From scratch. |
| Betweenness | `igraph::betweenness`, normalized by `(n − 1)(n − 2)/2`. |
| Katz's prestige | Eigenvector of the column-normalized adjacency matrix. From scratch. |
| Eigenvector | Power iteration, 12 iterations. From scratch. |
| Bonacich | `sna::bonpow` with exponent `0.5`. |
| Katz–Bonacich (König et al.) | `(I + βA⁺ − γA⁻)⁻¹ Γ`, where `A⁺` is friendship, `A⁻` is enmity, and `Γᵢ = 1 / (1 + β dᵢ⁺ − γ dᵢ⁻)`. From scratch. |

The König et al. centrality uses `β = 0.3` and `γ = 0.2`. These are placeholder values, not estimates. A negative `Γᵢ` is set to `0`.

[code_validity_check.pdf](sudan_data_analysis/code_validity_check.pdf) checks each measure against hand calculations on small example networks.

---

## 4. Reproducibility notes

- **Determinism.** The matrices and centralities involve no randomness.
- **Katz's prestige.** The script takes the second eigenvector (`unit_eigenvectors[, 2]`), and the choice is marked in the code as unresolved. Treat this column as provisional.
- **Sample vs. paper.** The paper's network has 102 groups. This repository's 199-event extract gives 51 actors, so the matrices here do not reproduce the paper's network one-to-one.
- **Data snapshot.** Both CSVs are fixed ACLED exports. ACLED revises past events, so a fresh download will give somewhat different numbers.
- **Duplicate data.** `data/` holds identical copies of the two CSVs. `data/Sudan_2003_to_2011.csv` is the same file as `2003-01-01-2011-12-31-Northern_Africa-Sudan.csv`. The script reads the copy in `sudan_data_analysis/`.

---

## 5. Output data dictionary

### `Friendship_matrix.xlsx`, `Enmity_matrix.xlsx`, `Resultant_matrix.xlsx`

51 × 51 matrices. The first column and the header row hold ACLED actor names in the same order.

| Value | Friendship | Enmity | Resultant |
|---|---|---|---|
| `1` | allies | enemies | allies |
| `0` | no tie | no tie | no tie, or both allied and hostile |
| `−1` | — | — | enemies |

### `cent_mat` (R session)

One row per actor, one column per measure: `Degree centrality`, `Closeness centrality`, `Betweenness centrality`, `Katzs prestige`, `Eigenvector centrality`, `Bonacich centrality`, `Katz-Bonacich centrality`.

---

## Historical context document

[sudan_historical_context/hist_context_sudan_war.pdf](sudan_historical_context/hist_context_sudan_war.pdf) covers Sudan's history from British–Egyptian rule through independence and the civil wars, as background for the network analysis.

---

## Data source

Event data comes from the **Armed Conflict Location & Event Data Project (ACLED)**, <https://acleddata.com>. Use of the data is subject to ACLED's terms of use.

---

## References

- Fernandes, M., Melo, A., Rubbini, C., & Centorrino, S. *Sudan Conflict: A Network Approach.* Working paper ([Sudan_Conflict_MainPaper.pdf](Sudan_Conflict_MainPaper.pdf)).
- König, M. D., Rohner, D., Thoenig, M., & Zilibotti, F. (2017). Networks in conflict: Theory and evidence from the great war of Africa. *Econometrica*, 85(4), 1093–1132.
- Provenzano, S., & Bull, H. (2023). *The Local Economic Impact of Mineral Mining in Africa: Evidence from Four Decades of Satellite Imagery.* arXiv:2111.05783. <https://arxiv.org/abs/2111.05783>

Code: <https://github.com/DivergenceTheorem/conflict-networks>
