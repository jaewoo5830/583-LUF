#include "llvm/Analysis/BlockFrequencyInfo.h"
#include "llvm/Analysis/BranchProbabilityInfo.h"
#include "llvm/Analysis/LoopInfo.h"
#include "llvm/Analysis/LoopIterator.h"
#include "llvm/Analysis/LoopNestAnalysis.h"
#include "llvm/Analysis/LoopPass.h"
#include "llvm/IR/CFG.h"
#include "llvm/IR/Instructions.h"
#include "llvm/IR/LLVMContext.h"
#include "llvm/IR/PassManager.h"
#include "llvm/Passes/PassBuilder.h"
#include "llvm/Passes/PassPlugin.h"
#include "llvm/Support/Debug.h"
#include "llvm/Support/raw_ostream.h"
#include "llvm/Transforms/Scalar/LoopPassManager.h"
#include "llvm/Transforms/Utils/BasicBlockUtils.h"
#include "llvm/Transforms/Utils/LoopUtils.h"
#include "llvm/IR/DebugLoc.h"
#include "llvm/Analysis/ScalarEvolution.h"
#include "llvm/Analysis/ScalarEvolutionExpressions.h"

#include <vector>
#include <unordered_set>
#include <iostream>
#include <string>
#include <fstream>

using namespace llvm;

namespace {
  struct FeaturePass : public PassInfoMixin<FeaturePass> {

    std::vector<unsigned int> countUseDef(Loop* L) {
      unsigned int defCount = 0;
      std::unordered_set<Value*> uses;
      for (BasicBlock* BB: L->getBlocks()) {
        for (Instruction& I: *BB) {
          if (!I.getType()->isVoidTy()) {
            ++defCount;
          }

          for (Use &U: I.operands()) {
            Value *V = U.get();
            uses.insert(V);
          }
        }
      }
      return {(unsigned int)uses.size(), defCount};
    }

    uint64_t getTripCount(Loop* L, llvm::BlockFrequencyAnalysis::Result &bfi){
      BasicBlock *header = L->getHeader();
      return bfi.getBlockProfileCount(header).value_or(0);
    }

    // unsigned int getCycleLength(Loop* L){
    //   llvm::Loop::LocRange range = L->getLocRange();
    //   return (range.getEnd().getLine() - range.getStart().getLine());
    // }
    
    std::vector<unsigned int> countLoopOps(Loop* L) {
      unsigned int total = 0, fp = 0, br = 0, mem = 0;
      for (BasicBlock* BB: L->getBlocks()) {
        for (Instruction& I: *BB) {
          ++total;
          unsigned int opcode = I.getOpcode();
          // Branch Instruction
          if (opcode == Instruction::Br || opcode == Instruction::Switch || opcode == Instruction::IndirectBr) {
            ++br;
          }
          // Floating-point Instruction
          else if (opcode == Instruction::FAdd || opcode == Instruction::FSub || opcode == Instruction::FMul || opcode == Instruction::FDiv 
                || opcode == Instruction::FDiv || opcode == Instruction::FCmp) {
            ++fp;
          }
          // Memory Instruction
          else if (opcode == Instruction::Alloca || opcode == Instruction::Load || opcode == Instruction::Store || opcode == Instruction::GetElementPtr 
                  || opcode == Instruction::Fence || opcode == Instruction::AtomicCmpXchg || opcode == Instruction::AtomicRMW) {
            ++mem;
          }
        }
      }
      return {total, fp, br, mem};
    }

    unsigned int getLoopDepth(Loop* L) {
      Loop* curr = L;
      unsigned int depth = 1;
      std::vector<Loop*> subLoopVec = curr->getSubLoops();
      while (!subLoopVec.empty()) {
        ++depth;
        curr = subLoopVec[0];
        subLoopVec = curr->getSubLoops();
      }
      return depth;
    }
    
    void extractLoopFeatures(Loop* L, llvm::BlockFrequencyAnalysis::Result &bfi, llvm::BranchProbabilityAnalysis::Result &bpi) {
      unsigned int depth = getLoopDepth(L);
      uint64_t tripCount = getTripCount(L, bfi);
      std::vector<unsigned int> loopOps = countLoopOps(L); // [total, fp, br, mem]
      std::vector<unsigned int> useDef = countUseDef(L); // [# uses, # defs]

      // output to file
      std::ofstream of;
      of.open("demo_data.csv", std::ofstream::out | std::ofstream::app);  // TODO change filename to reflect demo or actual run
      // std::cout << "HI" << std::endl;
      // of << "Depth,TripCount,Total,FP,BR,Mem,# Uses,# Defs" << std::endl;
      of << depth << "," << tripCount << "," << loopOps[0] << "," << loopOps[1] << "," << loopOps[2] << "," << loopOps[3] << "," << useDef[0] << "," << useDef[1] << std::endl;
      of.close();           
    }
    

    PreservedAnalyses run(Function &F, FunctionAnalysisManager &FAM) {
      llvm::BlockFrequencyAnalysis::Result &bfi = FAM.getResult<BlockFrequencyAnalysis>(F);
      llvm::BranchProbabilityAnalysis::Result &bpi = FAM.getResult<BranchProbabilityAnalysis>(F);
      llvm::LoopAnalysis::Result &li = FAM.getResult<LoopAnalysis>(F);
      // llvm::LoopNestAnalysis::Result &lni = LAM.getResult<LoopNestAnalysis>(F);
      for (Loop* L: li) {
        if (F.getName().str().find("example") != std::string::npos) {
          extractLoopFeatures(L, bfi, bpi);
        }
      }

      return PreservedAnalyses::all();
    }
  };
}

extern "C" ::llvm::PassPluginLibraryInfo LLVM_ATTRIBUTE_WEAK llvmGetPassPluginInfo() {
  return {
    LLVM_PLUGIN_API_VERSION, "FeaturePass", "v0.1",
    [](PassBuilder &PB) {
      PB.registerPipelineParsingCallback(
        [](StringRef Name, FunctionPassManager &FPM,
        ArrayRef<PassBuilder::PipelineElement>) {
          if(Name == "feature-pass"){
            FPM.addPass(FeaturePass());
            return true;
          }
          return false;
        }
      );
    }
  };
}