# URL Extraction Test Scripts

Two test scripts for validating URL metadata extraction:

## 1. `test_url_extraction.swift` - Integrated Version

This script integrates with the app's modules (`URLContentExtractor`, `LLMManager`).

**Usage:**
- Add to your Xcode project as a test target
- Requires the app to be running with a loaded LLM model
- Best for testing within the app context

**To run:**
```bash
# From Xcode: Add to test target and run
# Or from command line (if modules are accessible):
swift test_url_extraction.swift
```

## 2. `test_url_extraction_standalone.swift` - Standalone Version

This script can run independently without the app's modules. It supports multiple LLM providers.

**Usage:**

### Option 1: OpenAI API
```bash
export OPENAI_API_KEY='your-api-key'
export OPENAI_MODEL='gpt-4o-mini'  # Optional, defaults to gpt-4o-mini
chmod +x test_url_extraction_standalone.swift
./test_url_extraction_standalone.swift
```

### Option 2: Anthropic API
```bash
export ANTHROPIC_API_KEY='your-api-key'
export ANTHROPIC_MODEL='claude-3-haiku-20240307'  # Optional
chmod +x test_url_extraction_standalone.swift
./test_url_extraction_standalone.swift
```

### Option 3: Ollama (Local LLM)
```bash
# Install Ollama first: brew install ollama
# Start Ollama: ollama serve
# Pull a model: ollama pull llama3.2

export OLLAMA_MODEL='llama3.2'  # Optional, defaults to llama3.2
export OLLAMA_URL='http://localhost:11434'  # Optional
chmod +x test_url_extraction_standalone.swift
./test_url_extraction_standalone.swift
```

### Option 4: Mock (for testing structure)
The script will fall back to Ollama if no API keys are found. If Ollama is not available, it will fail with helpful error messages.

## Test Data

Both scripts read URLs from `TODO.md` in the same directory. The expected results are hardcoded in the scripts for comparison.

## Expected Output

The scripts will:
1. Extract content from each URL
2. Call the LLM to extract metadata (title, description, tags)
3. Compare results with expected values
4. Print a summary with match percentages

## Example Output

```
🚀 Starting URL Extraction Tests
Reading URLs from TODO.md...

Found 8 URLs to test

✅ Using OpenAI API (model: gpt-4o-mini)

📋 Testing 1/8: https://github.com/Nixtla/neuralforecast
   ⏳ Extracting content...
   ✅ Content extracted (15234 characters)
   ⏳ Calling LLM...
   ✅ LLM response received

================================================================================
Test 1: https://github.com/Nixtla/neuralforecast
================================================================================

📘 Title: NeuralForecast
🧠 Description: A comprehensive collection of neural forecasting models...
🏷️ Tags: time-series, forecasting, deep-learning, transformers, neural-networks, python

--- Expected vs Actual ---

Title: ✅
  Expected: NeuralForecast
  Actual:   NeuralForecast

Description: ✅
  Expected: A comprehensive collection...
  Actual:   A comprehensive collection...

Tags: ✅ (6/6 match)
  Expected: time-series, forecasting, deep-learning, transformers, neural-networks, python
  Actual:   time-series, forecasting, deep-learning, transformers, neural-networks, python

...

📊 TEST SUMMARY
================================================================================

Results: 8 URLs tested
Title matches: 8/8 (100%)
Description matches: 7/8 (87%)
Tag matches: 8/8 (100%)

✅ Tests completed!
```

