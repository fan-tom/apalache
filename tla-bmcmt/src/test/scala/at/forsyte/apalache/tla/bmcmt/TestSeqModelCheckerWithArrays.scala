package at.forsyte.apalache.tla.bmcmt

import at.forsyte.apalache.tla.bmcmt.analyses.ExprGradeStoreImpl
import at.forsyte.apalache.tla.bmcmt.smt.{RecordingSolverContext, SolverConfig}
import org.junit.runner.RunWith
import org.scalatest.Outcome
import org.scalatest.junit.JUnitRunner

// TODO: Extend TestSeqModelCheckerTrait when development in the "arrays" encoding progresses

//@RunWith(classOf[JUnitRunner])
class TestSeqModelCheckerWithArrays {
  /*
  override protected def withFixture(test: OneArgTest): Outcome = {
    val solver = RecordingSolverContext.createZ3(None, SolverConfig(debug = false, profile = false, 0))
    val rewriter = new SymbStateRewriterImpl(solver, new ExprGradeStoreImpl)
    test(rewriter)
  }
   */
}
