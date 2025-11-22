# Extraction Prompt Improvements - v2

## Date: November 22, 2025

### Problem Identified
The extraction was producing **raw abstracts** instead of **meaningful, processed summaries**. The LLM was acting as a copy-paste tool rather than an analytical assistant.

### Root Cause
The previous prompt emphasized **extraction** over **analysis**:
- "Extract metadata"
- "Extract the exact title"
- Instructions focused on finding and copying information
- No emphasis on synthesis or understanding

### Solution: Structured Reasoning Approach

Completely revamped the prompt to emphasize:

#### 1. **Analysis Over Extraction**
```
"You are an expert assistant specialized in reading and extracting information..."
"Your job is to: Read and understand... Produce a concise, high-value analysis..."
```

#### 2. **Synthesized Summaries**
```
"SUMMARY (CRITICAL - This is NOT just copying the abstract!)
- Write a SYNTHESIZED summary in YOUR OWN WORDS (3-5 sentences)
- DO NOT just copy-paste the abstract or introduction
- ANALYZE and SYNTHESIZE the information"
```

#### 3. **Structured Reasoning**
For research papers: **Problem → Method → Key findings → Significance**
For tools/libraries: **What it does → How it helps → Why use it**

#### 4. **Concrete, Specific Value**
```
"WHY IS THIS USEFUL? (CRITICAL - Be SPECIFIC and CONCRETE!)
- WHO BENEFITS: Which profiles?
- USE CASES: What can someone DO?
- CONCRETE SCENARIOS: 2-3 realistic examples
- SPECIFIC ADVANTAGES: What makes this better/different/novel?
- BE CONCRETE: 'Reduces memory by 50%', 'Enables offline processing'"
```

#### 5. **Context-Aware Guidance**
- Detects paper vs. repository vs. article
- Provides specific instructions for each type
- Adjusts content length (8000 chars for papers, 5000 for others)

### Key Improvements

| Aspect | Before | After |
|--------|--------|-------|
| **Approach** | Extract metadata | Analyze and synthesize |
| **Summary** | Copy abstract | Synthesize in own words |
| **Value** | Generic benefits | Concrete use cases + metrics |
| **Content** | 6000 chars | 8000 chars for papers |
| **Instructions** | "Extract the exact..." | "Analyze... Synthesize... Understand..." |
| **Emphasis** | Information retrieval | Understanding + Analysis |

### Prompt Structure

```
1. Expert Role Definition
   ↓
2. Context Detection (Paper/Repo/Article)
   ↓
3. Specific Guidance for Content Type
   ↓
4. Task Breakdown:
   - Title (exact)
   - Summary (SYNTHESIZED, not copied)
   - What Is It (clear definition)
   - Why Useful (CONCRETE scenarios)
   - Category
   - Tags
   ↓
5. Critical Instructions (repeated emphasis)
   ↓
6. Content + Metadata
   ↓
7. Final Reminder + JSON Output
```

### Example Transformation

**Before (Raw Abstract Copy)**:
> "We propose a novel attention mechanism for transformers that reduces computational complexity..."

**After (Synthesized Analysis)**:
> "This research addresses the quadratic complexity problem in transformer attention mechanisms by introducing a sparse attention pattern that maintains model quality while reducing memory usage by 50%. The approach enables processing of longer sequences (up to 16K tokens) on standard GPUs, making it practical for document-level tasks. Experiments show comparable accuracy to full attention with 3x faster training."

### Testing Recommendations

Test with:
1. **arXiv paper**: https://arxiv.org/abs/2402.06196
   - Should get: Synthesized summary explaining problem/method/impact
   - Should NOT get: Raw abstract text

2. **GitHub repo**: Popular ML library
   - Should get: What it does, how it helps, who uses it
   - Should NOT get: Just the README description

3. **Blog article**: Technical post
   - Should get: Main ideas, practical takeaways
   - Should NOT get: Copy of introduction

### Success Criteria

✅ Summary is in LLM's own words, not copy-pasted
✅ "Why useful" contains concrete scenarios and metrics
✅ Shows understanding of the content, not just extraction
✅ Practical value is specific and actionable
✅ Avoids generic marketing language

---

## Implementation Notes

- Increased content length to 8000 chars for papers (was 6000)
- Added GitHub-specific guidance
- Emphasized synthesis 3 times in the prompt
- Added "CRITICAL" markers for important instructions
- Structured output format with clear examples
- Final reminder before JSON output to reinforce key points
