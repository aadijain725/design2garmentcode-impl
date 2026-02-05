
import copy
import logging
import time
from dataclasses import dataclass, field
from typing import List, Optional

from lmm_utils.core import MMUA
from lmm_utils.projector import input_caption2random_default_cption
from lmm_utils.predict_garmentcode_picture import Predictor

logger = logging.getLogger('design2garmentcode.pipeline')


@dataclass
class PipelineResult:
    """Result of a unified design pipeline run."""
    input_images: List[str] = field(default_factory=list)
    input_text: str = ''
    primary_image: Optional[str] = None
    gpt_response: Optional[str] = None
    gpt_design_list: Optional[list] = None
    gpt_design_params: Optional[dict] = None
    caption: Optional[list] = None
    yaml_spec: Optional[dict] = None
    pattern_json_path: Optional[str] = None
    pattern_spec: Optional[dict] = None
    sim_output_path: Optional[str] = None
    mesh_path: Optional[str] = None
    render_path: Optional[str] = None

    def as_legacy_tuple(self):
        """Return (gpt_response, gpt_design_params, gpt_design_list) for backward compat."""
        return (self.gpt_response, self.gpt_design_params, self.gpt_design_list)


def _retry_call(fn, *args, max_retries=1, fail_msg="Operation failed", **kwargs):
    """Call fn(*args, **kwargs) with up to max_retries retries on exception.

    Returns:
        (result, None) on success, or (None, error_message) on final failure.
    """
    last_error = None
    for attempt in range(1 + max_retries):
        try:
            result = fn(*args, **kwargs)
            return result, None
        except Exception as e:
            last_error = e
            if attempt < max_retries:
                logger.warning(
                    "Retry %d/%d for %s: %s", attempt + 1, max_retries,
                    fn.__name__, str(e))
            else:
                logger.error(
                    "All %d attempts failed for %s: %s",
                    1 + max_retries, fn.__name__, str(e))
    return None, f"{fail_msg} ({last_error})"


class Agent():
    def __init__(self, api_key=None, base_url=None, model=None, text_model=None, model_init=True):

        self.mmua = MMUA(api_key=api_key, base_url=base_url, model=model, text_model=text_model)
        self.dsl_ga = Predictor(model_init=model_init)

    # ------------------------------------------------------------------
    # Unified pipeline
    # ------------------------------------------------------------------

    def design(self, images=None, text=None):
        """Unified entry point for all new-design pipelines.

        Args:
            images: list of image paths (0, 1, or N).
            text: optional text prompt.

        Returns:
            PipelineResult
        """
        images = images or []
        text = text or ''
        pipeline_start = time.time()

        route = 'images+text' if images and text else (
            'images-only' if images else 'text-only')
        logger.info(
            "design() entry: route=%s, num_images=%d, text_len=%d",
            route, len(images), len(text))

        result = PipelineResult(
            input_images=list(images),
            input_text=text,
            primary_image=images[0] if images else None,
        )

        gpt_design_list = None
        gpt_response = None

        # ------ Stage 1: LLM recognition ------
        stage_start = time.time()
        if images and text:
            # Image(s) + text: two-stage process
            # Stage 1a: image recognition
            if len(images) == 1:
                (img_result, err) = _retry_call(
                    self.mmua.picture_gpt, images[0],
                    fail_msg="Generation failed, please try another image or prompt.")
            else:
                (img_result, err) = _retry_call(
                    self.mmua.pictures_gpt, images,
                    fail_msg="Generation failed, please try other images or prompt.")

            if err:
                logger.error("Image recognition failed: %s", err)
                result.gpt_response = err
                return result

            gpt_design_list, gpt_response = img_result
            logger.info(
                "Image recognition done in %.1fs, end_list length=%d",
                time.time() - stage_start, len(gpt_design_list))

            # Stage 1b: text authoring on top of image caption
            stage_start = time.time()
            (text_result, err) = _retry_call(
                self.mmua.text_forusermodel_gpt,
                caption=gpt_design_list, user_input=text,
                fail_msg="Authoring failed, please try another instruction.")

            if err:
                logger.error("Text authoring failed: %s", err)
                result.gpt_response = err
                return result

            gpt_design_list, gpt_response = text_result
            logger.info(
                "Text authoring done in %.1fs, end_list length=%d",
                time.time() - stage_start, len(gpt_design_list))

        elif images:
            # Image(s) only
            if len(images) == 1:
                (img_result, err) = _retry_call(
                    self.mmua.picture_gpt, images[0],
                    fail_msg="Generation failed, please try another image.")
            else:
                (img_result, err) = _retry_call(
                    self.mmua.pictures_gpt, images,
                    fail_msg="Generation failed, please try other images.")

            if err:
                logger.error("Image recognition failed: %s", err)
                result.gpt_response = err
                return result

            gpt_design_list, gpt_response = img_result
            logger.info(
                "Image recognition done in %.1fs, end_list length=%d",
                time.time() - stage_start, len(gpt_design_list))

        elif text:
            # Text only
            (text_result, err) = _retry_call(
                self.mmua.text_gpt, text,
                fail_msg="Generation failed, please try another prompt.")

            if err:
                logger.error("Text generation failed: %s", err)
                result.gpt_response = err
                return result

            gpt_design_list, gpt_response = text_result
            logger.info(
                "Text generation done in %.1fs, end_list length=%d",
                time.time() - stage_start, len(gpt_design_list))
        else:
            result.gpt_response = "No input provided. Supply images, text, or both."
            return result

        # ------ Stage 2: Caption fill + YAML conversion ------
        result.gpt_response = gpt_response

        if gpt_design_list is not None:
            gpt_design_list = input_caption2random_default_cption(gpt_design_list)
            result.caption = list(gpt_design_list)

            caption2yaml_kwargs = {}
            if images:
                caption2yaml_kwargs['image_path'] = images[0]

            gpt_design_params = self.dsl_ga.caption2yaml(
                gpt_design_list, **caption2yaml_kwargs)

            result.gpt_design_list = gpt_design_list
            result.gpt_design_params = gpt_design_params

        logger.info(
            "design() complete in %.1fs, has_params=%s",
            time.time() - pipeline_start,
            result.gpt_design_params is not None)

        return result

    # ------------------------------------------------------------------
    # Legacy wrappers (return old tuple format)
    # ------------------------------------------------------------------

    def text_design(self, text_prompt):
        logger.info("text_design (legacy wrapper) called")
        return self.design(text=text_prompt).as_legacy_tuple()

    def picture_design(self, img_url):
        logger.info("picture_design (legacy wrapper) called")
        return self.design(images=[img_url]).as_legacy_tuple()

    def picture_text_design(self, img_url, text_prompt):
        logger.info("picture_text_design (legacy wrapper) called")
        return self.design(images=[img_url], text=text_prompt).as_legacy_tuple()

    # ------------------------------------------------------------------
    # Diff-based methods (keep unique logic, use _retry_call for retries)
    # ------------------------------------------------------------------

    def modify_design(self, design_list, text_prompt, design_params):
        gpt_design_list = None
        gpt_response = None
        gpt_design_params = None

        (call_result, err) = _retry_call(
            self.mmua.text_forusermodel_gpt, design_list,
            user_input=text_prompt,
            fail_msg="modify_fail, please input prompt again")

        if err:
            logger.error("modify_design failed: %s", err)
            gpt_response = err
        else:
            gpt_design_list, gpt_response = call_result

        if gpt_design_list is not None:
            gpt_design_list = input_caption2random_default_cption(gpt_design_list)
            more_caption_list = set(gpt_design_list) - set(design_list)
            gpt_design_params = self.dsl_ga.caption2yaml(
                more_caption_list, modify=True,
                cache_input_design_data=copy.deepcopy(design_params))
        return gpt_response, gpt_design_params, gpt_design_list

    def stress_design(self, design_list, img_url, design_params):
        gpt_design_list = None
        gpt_response = None
        gpt_design_params = None

        (call_result, err) = _retry_call(
            self.mmua.picture_caption_gpt_red, img_url,
            caption=design_list,
            fail_msg="stress_fail, please input prompt and picture again")

        if err:
            logger.error("stress_design failed: %s", err)
            gpt_response = err
        else:
            gpt_design_list, gpt_response = call_result

        if gpt_design_list is not None:
            gpt_design_list = input_caption2random_default_cption(gpt_design_list)
            more_caption_list = set(gpt_design_list) - set(design_list)
            gpt_design_params = self.dsl_ga.caption2yaml(
                more_caption_list, modify=True,
                cache_input_design_data=copy.deepcopy(design_params))

        return gpt_response, gpt_design_params, gpt_design_list
