## Fetal Fraction (FF) Estimation Protocol
This protocol describes the determination of fetal fraction from cell-free DNA (cfDNA) size profiles using fragment length distribution and empirical linear calibration.
#### 1. Fragment Ratio Calculation
Circulating cell-free DNA in maternal plasma consists of shorter fetal fragments (peaking around 143 bp) and longer maternal fragments (peaking around 166 bp). The relative ratio of short-to-long fragments serves as a proxy for fetal cfDNA abundance.

Mathematical Formula

        $$Ratio = \frac{\sum \text{Fragments with length } \in [100\text{ bp}, 150\text{ bp}]}{\sum \text{Fragments with length } \in [160\text{ bp}, 200\text{ bp}]}$$

        Short fragments: Sum of sequenced reads with fragment lengths between 100 bp and 150 bp (enriched for fetal-derived cfDNA).
        Long fragments: Sum of sequenced reads with fragment lengths between 160 bp and 200 bp (predominantly maternal mono-nucleosomal cfDNA).

#### 2. Linear Calibration Model
To convert the calculated sample-specific $Ratio$ into an absolute Fetal Fraction ($FF$), a standard linear regression model calibrated against reference samples (e.g., male pregnancies quantified via chromosome Y read counts) is applied.

Linear Regression Formula

        y = a * x + b
        FF = (Slope * Ratio) + Intercept

        y = Fetal Fraction ($FF$): The estimated proportion of fetal cfDNA.
        x = Fragment Ratio ($Ratio$): The computed predictor variable from fragment sizing.
        a = Slope ($Slope$): The rate of change in fetal fraction per unit change in fragment ratio.
        b = Y-Intercept ($Intercept$): The baseline offset value where the regression line intersects the Y-axis.

The fetal fraction was measured by using PCR within XY samples to reliably determine the amount of fetal fraction.