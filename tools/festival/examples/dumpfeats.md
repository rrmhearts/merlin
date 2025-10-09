## The `dumpfeats` Application

The `dumpfeats` application is a powerful command-line utility distributed with the Festival Speech Synthesis System. Its primary purpose is to **extract linguistic features** from a Festival Utterance structure and save them to a file.

In essence, `dumpfeats` acts as a bridge between Festival's rich, symbolic linguistic analysis (the front-end) and the numerical requirements of statistical or neural network-based synthesis models (the back-end), such as those built with the [Merlin Toolkit](http://data.cstr.ed.ac.uk/merlin/). It systematically traverses an utterance, and for each specified unit (like a phoneme or syllable), it extracts a vector of features and writes it to an output file.

### Core Functionality

1.  **Input**: It takes one or more pre-generated Festival Utterance files (`.utt`) as input. An utterance file is a snapshot of the entire linguistic structure for a piece of text after it has been processed by Festival's front-end.
2.  **Feature Definition**: It requires a separate Scheme file that defines *which* features to extract. These feature definitions can range from simple properties (e.g., the name of the current phoneme) to complex queries that navigate the entire utterance structure (e.g., the stress level of the parent syllable of the phoneme two segments from now).
3.  **Output**: It generates a text file where each line corresponds to a unit (e.g., a phoneme), and the columns on that line are the extracted feature values for that unit. This output file is often referred to as a **label file** (e.g., `.lab`).

### Command-Line Usage

The basic syntax for `dumpfeats` is as follows:

```bash
dumpfeats [options] -eval <features.scm> -relation <relation_name> -output <output.txt> <file1.utt> [file2.utt ...]
```

**Key Options:**

*   `-relation <relation_name>`: **(Required)** Specifies the basic unit from which features should be extracted. This is typically `Segment` (for phonemes) but could also be `Syllable` or `Word`.
*   `-eval <features.scm>`: **(Required)** Provides a Scheme file containing a list of feature-extracting functions. The output of these functions will form the columns of the output file.
*   `-output <output_file>`: **(Required)** The path to the file where the extracted features will be saved.
*   `-desc <features.desc>`: An alternative to `-eval`. Instead of evaluating the functions, it uses the same feature file to generate a human-readable description of the feature set, which is useful for documentation.
*   `-feats <feature_file>`: An older, deprecated way to specify features. `-eval` is preferred.

### The Feature Definition File (`-eval`)

The power of `dumpfeats` comes from the feature definition file. This is a Scheme file containing a single list of feature functions. Each item in the list corresponds to a column in the output file.

These "functions" are often path expressions that navigate the Utterance Structure.

**Example Feature File (`features.scm`):**
```scheme
(
  ;; Phonetic context
  p.name                 ;; Previous phoneme's name
  name                   ;; Current phoneme's name
  n.name                 ;; Next phoneme's name

  ;; Positional features
  pos_in_syl             ;; Position of this phoneme in the syllable (forward)
  syl_final              ;; Is this phoneme the last in the syllable? (1 or 0)

  ;; Syllable and Word level features
  R:SylStructure.parent.stress         ;; Stress of the parent syllable (1 or 0)
  R:SylStructure.parent.syl_numphones  ;; Number of phonemes in the parent syllable
  R:SylStructure.parent.parent.name    ;; Name of the parent word
)
```

**Understanding Path Expressions:**
*   `p.name`, `n.name`: Access the `name` feature of the **p**revious or **n**ext item in the current `Relation`.
*   `R:RelationName.path`: This is a powerful expression. It starts from the current item, finds the related item in `RelationName`, and then follows the path.
    *   In `R:SylStructure.parent.stress`:
        1.  `R:SylStructure`: From the current `Segment`, find the `Syllable` that contains it via the `SylStructure` relation.
        2.  `.parent`: Navigate "up" from that `Syllable` item to its parent item (in this case, also the syllable itself in this structure).
        3.  `.stress`: Extract the `stress` feature from that syllable.

### Practical Example

Let's extract features for the sentence "This is a test."

**Step 1: Create an Utterance File**

First, use Festival to process the text and save the resulting utterance structure.

```bash
# Create a text file
echo "This is a test." > test.txt

# Run festival to generate the .utt file
festival --batch <<EOF
(utt.save (utt.process (Utterance Text (load_text_file "test.txt"))) "test.utt")
EOF
```
This creates `test.utt`, which contains all the linguistic information for the sentence.

**Step 2: Create a Feature Definition File**

Save the example feature list from above into a file named `features.scm`.

**Step 3: Run `dumpfeats`**

Now, execute `dumpfeats` to extract the features for each `Segment` (phoneme).

```bash
dumpfeats -eval features.scm -relation Segment -output test.lab test.utt
```

**Step 4: Analyze the Output (`test.lab`)**

The generated file `test.lab` will look something like this (output may vary slightly based on the voice's phoneset and lexicon):

```
# dh 1 1 0 1 3 this
dh ih 1 2 0 1 3 this
ih s 1 3 1 1 3 this
s ih 1 1 1 0 2 iz
ih z 1 2 1 0 2 iz
z ax 1 1 1 0 1 a
ax t 1 1 1 0 4 test
t eh 1 2 0 0 4 test
eh s 1 3 0 0 4 test
s t 1 4 1 0 4 test
```

**Explanation of the first line:**
*   `#`: The previous phoneme is silence (`p.name`).
*   `dh`: The current phoneme is `dh` (`name`).
*   `1`: The position of this phoneme in the syllable is 1 (`pos_in_syl`).
*   `1`: It is the first phoneme (`pos_in_syl`).
*   `0`: It is not the last phoneme in the syllable (`syl_final`).
*   `1`: The parent syllable is stressed (`R:SylStructure.parent.stress`).
*   `3`: The syllable has 3 phonemes (`R:SylStructure.parent.syl_numphones`).
*   `this`: The parent word is "this" (`R:SylStructure.parent.parent.name`).

### Role in Merlin and Neural TTS

The output of `dumpfeats` is the **direct input** to neural synthesis models. In a typical Merlin workflow:

1.  A large text corpus is processed into thousands of `.utt` files.
2.  `dumpfeats` is run on all `.utt` files to generate a corresponding set of `.lab` (label) files.
3.  These label files, which are numerical representations of linguistic context, are used to train the duration model (to predict phoneme timing) and the acoustic model (to predict acoustic features like mel-cepstra from the linguistic features).

Without `dumpfeats`, there would be no way to convert the rich, symbolic output of Festival's front-end into the matrix of numbers that a neural network can understand.